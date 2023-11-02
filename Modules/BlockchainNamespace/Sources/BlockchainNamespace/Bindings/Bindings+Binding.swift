import Extensions
#if canImport(SwiftUI)
import SwiftUI
#endif

extension Bindings {

    public final class Binding: Hashable {

        public enum Result: CustomStringConvertible {
            case idle
            case requesting
            case success(Any, Metadata)
            case failure(Error, Metadata)
        }

        public let reference: Tag.Reference
        var compute: Compute.JSON?
        let property: Any?
        public let isSubscribed: Bool

        public private(set) var isUpToDate: Bool = true
        public private(set) var hasTransactionChanges: Bool = false
        public var isInTransaction: Bool { app?.state.data.isInTransaction ?? false }

        public private(set) var result: Result = .idle {
            didSet {
                guard (!isInTransaction && hasTransactionChanges) || result.isDifferent(from: oldValue) else { return }
                hasTransactionChanges = isInTransaction
                isUpToDate = false
                bindings?.didUpdate(self)
            }
        }

        public var isSynchronized: Bool { bindings?.isSynchronized ?? false }

        private let lock = NSRecursiveLock()
        private weak var bindings: BindingsProtocol?
        private var app: AppProtocol? { bindings?.app }
        private let identifier: ObjectIdentifier

        public internal(set) var depth = 0

        var update: (Any) -> Void = { _ in }
        private var set: (FetchResult, Result) throws -> Any = { _, _ in NSNull() }
        private var decode: (FetchResult) -> Void = { _ in }

        private var computeHandler: Compute.HandlerProtocol?
        private var subscription: AnyCancellable? {
            didSet { oldValue?.cancel() }
        }

        public var recursiveBindings: Set<Binding> { computeHandler?.recursiveBindings ?? [] }

        init(
            bindings: Bindings,
            property: Any?,
            subscribed: Bool,
            reference: Tag.Reference,
            compute: Compute.JSON? = nil
        ) {
            self.bindings = bindings
            self.depth = bindings.depth
            self.isSubscribed = subscribed
            self.identifier = ObjectIdentifier(bindings)
            self.property = property
            self.reference = reference
            self.compute = compute
            self.set = { f, _ in try f.get() }
        }

        func request() {
            lock.lock()
            defer { lock.unlock() }
            if case .requesting = result { return }
            if let returns = compute?.returns {
                return request(returns)
            }
            guard subscription.isNil else { return }
            result = .requesting
            if isSubscribed {
                subscription = app?.publisher(for: reference)
                    .sink(receiveValue: decode)
            } else {
                subscription = app?.get(reference)
                    .sink(receiveValue: decode)
            }
        }

        func request(_ returns: [String: Any]) {
            lock.lock()
            defer { lock.unlock() }
            guard let bindings, let app else { return }
            if isSubscribed, computeHandler.isNotNil { return }
            result = .requesting
            computeHandler = Compute.from(
                returns: returns,
                context: bindings.context,
                in: app,
                subscribed: isSubscribed,
                handle: decode
            )
        }

        func decode<T: Decodable & Equatable>(as type: T.Type) -> (FetchResult) -> Void {
            { [weak self] result in
                guard let self, let bindings else { return }
                lock.lock()
                defer { self.lock.unlock() }
                computeHandler = Compute.Handler(
                    app: bindings.app,
                    context: bindings.context,
                    result: result,
                    subscribed: isSubscribed,
                    type: T.self
                ) { [weak self] result in
                    guard let self else { return }
                    lock.lock()
                    defer { self.lock.unlock() }
                    do {
                        self.result = try .success(set(result.any(), self.result), result.metadata)
                    } catch {
                        self.result = .failure(error, result.metadata)
                    }
                }
            }
        }

        func unsubscribe() {
            lock.lock()
            defer { self.lock.unlock() }
            computeHandler = nil
            subscription = nil
        }

        func apply(asynchronously: Bool) {
            func apply() {
                guard !isUpToDate, let result = result.value?.any else { return }
                update(result)
                isUpToDate = true
            }
            if asynchronously {
                DispatchQueue.main.async { apply() }
            } else {
                apply()
            }
        }

        public static func == (lhs: Binding, rhs: Binding) -> Bool {
            guard lhs.reference == rhs.reference else { return false }
            guard lhs.identifier == rhs.identifier else { return false }
            guard
                lhs.property == nil && rhs.property == nil
                    || isEqual(lhs.property as Any, rhs.property as Any)
                    || (lhs.property as? any Identifiable)?.sameIdentity(as: rhs.property) ?? false
            else { return false }
            return true
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(reference)
            hasher.combine(identifier)
        }
    }
}

extension Identifiable {
    func sameIdentity(as other: Any?) -> Bool { id == (other as? Self)?.id }
}

extension Bindings.Binding.Result {

    public var description: String {
        switch self {
        case .idle: "idle"
        case .requesting: "requesting"
        case .success(let any, _): "\(any)"
        case .failure(let error, _): "\(error)"
        }
    }

    var isSynchronized: Bool {
        switch self {
        case .idle, .requesting: false
        case .success, .failure: true
        }
    }

    func isDifferent(from old: Self) -> Bool {
        switch (self, old) {
        case (.success(let new, _), .success(let old, _)): !isEqual(new, old)
        case (.success, _): true
        case (.failure, .failure): false
        case (.failure, _): true
        default: false
        }
    }

    public func get() throws -> Any {
        switch self {
        case .idle: throw "Value not yet requested"
        case .requesting: throw "Value is being requested"
        case .failure(let error, _): throw error
        case .success(let any, _): return any
        }
    }

    var value: (any: Any, metadata: Metadata)? {
        switch self {
        case .success(let value, let m): (value, m)
        case .idle, .requesting, .failure: nil
        }
    }

    var error: (any: Swift.Error, metadata: Metadata)? {
        switch self {
        case .failure(let err, let m): (err, m)
        case .idle, .requesting, .success: nil
        }
    }
}

extension Bindings.Binding: CustomStringConvertible {
    public var description: String {
        "Bindings.Binding(to: \(reference.tag), subscribed: \(isSubscribed), result: \(result))"
    }
}

extension Bindings.Binding {

    convenience init<Property: Decodable & Equatable>(
        _ bindings: Bindings,
        binding: SwiftUI.Binding<Property>,
        to reference: Tag.Reference,
        subscribed: Bool = true
    ) {
        self.init(
            bindings: bindings,
            property: binding,
            subscribed: subscribed,
            reference: reference
        )
        self.decode = decode(as: Property.self)
        self.update = { newValue in
            guard let property = newValue as? Property else { return }
            guard property != binding.wrappedValue else { return }
            binding.wrappedValue = property
        }
    }

    convenience init<T: Decodable & Equatable, Property: Decodable & Equatable>(
        _ bindings: Bindings,
        binding: SwiftUI.Binding<Property>,
        to reference: Tag.Reference,
        subscribed: Bool = true,
        map: @escaping (T) throws -> Property
    ) {
        self.init(
            bindings: bindings,
            property: binding,
            subscribed: subscribed,
            reference: reference
        )
        self.decode = decode(as: T.self)
        self.update = { newValue in
            guard let property = newValue as? Property else { return }
            guard property != binding.wrappedValue else { return }
            binding.wrappedValue = property
        }
        self.set = { result, _ in try map(result.value(as: T.self)) }
    }

    convenience init<Property: Decodable & Equatable>(
        _ bindings: Bindings,
        to reference: Tag.Reference,
        subscribed: Bool = true,
        as property: Property.Type
    ) {
        self.init(
            bindings: bindings,
            property: nil,
            subscribed: subscribed,
            reference: reference
        )
        self.decode = decode(as: Property.self)
        self.set = { result, _ in try result.value(as: Property.self) }
    }

    convenience init<Object: AnyObject>(
        _ bindings: Bindings,
        compute: Compute.JSON,
        subscribed: Bool = true,
        to object: Object?,
        _ property: ReferenceWritableKeyPath<Object, Any>
    ) {
        self.init(
            bindings: bindings,
            property: property,
            subscribed: subscribed,
            reference: blockchain.db.returns[].key(),
            compute: compute
        )
        self.update = { [weak object] value in object?[keyPath: property] = value }
        self.decode = { [weak self] r in
            do {
                self?.result = try .success(r.get(), r.metadata)
            } catch {
                self?.result = .failure(error, r.metadata)
            }
        }
    }

    convenience init<Object: AnyObject>(
        _ bindings: Bindings,
        reference: Tag.Reference,
        subscribed: Bool = true,
        to object: Object?,
        _ property: ReferenceWritableKeyPath<Object, Any>
    ) {
        self.init(
            bindings: bindings,
            property: property,
            subscribed: subscribed,
            reference: reference
        )
        self.update = { [weak object] value in object?[keyPath: property] = value }
        self.decode = { [weak self] r in
            do {
                self?.result = try .success(r.get(), r.metadata)
            } catch {
                self?.result = .failure(error, r.metadata)
            }
        }
    }

    convenience init<Object: AnyObject, Property: Equatable>(
        _ bindings: Bindings,
        reference: Tag.Reference,
        subscribed: Bool = true,
        to object: Object?,
        _ property: ReferenceWritableKeyPath<Object, Property>
    ) {
        self.init(
            bindings: bindings,
            property: property,
            subscribed: subscribed,
            reference: reference
        )
        self.update = { [weak object] value in
            guard let object else { return }
            if Property.self is any OptionalProtocol.Type {
                let result = value as? Property
                guard object[keyPath: property] != result else { return }
                object[keyPath: property] = result ?? (Property.self as? any OptionalProtocol.Type)?.none as! Property
            } else {
                guard let result = value as? Property else { return }
                guard object[keyPath: property] != result else { return }
                object[keyPath: property] = result
            }
        }
    }

    convenience init<Object: AnyObject, Property: Decodable & Equatable>(
        _ bindings: Bindings,
        reference: Tag.Reference,
        subscribed: Bool = true,
        to object: Object?,
        _ property: ReferenceWritableKeyPath<Object, Property>
    ) {
        self.init(
            bindings: bindings,
            property: property,
            subscribed: subscribed,
            reference: reference
        )
        self.set = { result, _ in try result.value(as: Property.self) }
        self.update = { [weak object] value in
            guard let object else { return }
            if Property.self is any OptionalProtocol.Type {
                let result = value as? Property
                guard object[keyPath: property] != result else { return }
                object[keyPath: property] = result ?? (Property.self as? any OptionalProtocol.Type)?.none as! Property
            } else {
                guard let result = value as? Property else { return }
                guard object[keyPath: property] != result else { return }
                object[keyPath: property] = result
            }
        }
        self.decode = decode(as: Property.self)
    }

    convenience init<Object: AnyObject, T: Decodable & Equatable, Property: Decodable & Equatable>(
        _ bindings: Bindings,
        reference: Tag.Reference,
        subscribed: Bool = true,
        to object: Object?,
        _ property: ReferenceWritableKeyPath<Object, Property>,
        map: @escaping (T) throws -> Property
    ) {
        self.init(
            bindings: bindings,
            property: property,
            subscribed: subscribed,
            reference: reference
        )
        self.set = { result, _ in try map(result.value(as: T.self)) }
        self.update = { [weak object] value in
            guard let object else { return }
            if Property.self is any OptionalProtocol.Type {
                let result = value as? Property
                guard object[keyPath: property] != result else { return }
                object[keyPath: property] = result ?? (Property.self as? any OptionalProtocol.Type)?.none as! Property
            } else {
                guard let result = value as? Property else { return }
                guard object[keyPath: property] != result else { return }
                object[keyPath: property] = result
            }
        }
        self.decode = decode(as: T.self)
    }
}
