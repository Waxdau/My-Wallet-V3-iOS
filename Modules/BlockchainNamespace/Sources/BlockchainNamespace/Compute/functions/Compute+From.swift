import Extensions

extension Compute {

    struct From: ReturnsKeyword {
        let reference: Tag.Reference
        let context: Tag.Context?
    }
}

extension Compute.From {

    static func handler(
        for data: Any,
        defaultingTo defaultValue: Any?,
        context: Tag.Context,
        in app: AppProtocol,
        subscribed: Bool,
        handle: @escaping (FetchResult) -> Void
    ) -> Compute.HandlerProtocol? {
        var subscription: AnyCancellable?
        return Compute.Handler(
            app: app,
            context: context,
            result: .value(data, Compute.metadata()),
            subscribed: subscribed,
            type: Compute.From.self
        ) { result in
            subscription?.cancel()
            func on(_ error: Error) {
                if let defaultValue {
                    handle(.value(defaultValue, Compute.metadata()))
                } else {
                    handle(.error(error, Compute.metadata()))
                }
            }
            do {
                let from = try Self.from(result.get())
                subscription = try app.publisher(
                    for: from.reference.ref(
                        to: context + (from.context ?? [:]),
                        in: app
                    ).validated(),
                    computeConfiguration: false
                )
                .receive(on: DispatchQueue.main)
                .sink { result in
                    do {
                        try handle(.value(result.get(), Compute.metadata()))
                    } catch { on(error) }
                }
            } catch {
                on(error)
            }
        }
    }
}

extension Compute.From {
    var description: String { "From(reference: \(reference))" }
}
