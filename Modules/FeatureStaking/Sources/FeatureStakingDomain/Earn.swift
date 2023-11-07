import Blockchain

// earn/eligible

public typealias EarnEligibility = [String: EarnCurrencyEligibility]
public struct EarnCurrencyEligibility: Hashable, Decodable {
    public var eligible: Bool
}

// earn/eligible

public struct EarnUserRates: Hashable, Decodable {
    public var rates: [String: EarnRate]
}

extension EarnUserRates {

    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: AnyCodingKey.self)
            self.rates = try container.decode([String: EarnRate].self, forKey: "rates")
        } catch {
            let container = try decoder.singleValueContainer()
            self.rates = try container.decode([String: EarnRate].self)
        }
    }
}

public struct EarnBondingTxsRequest: Decodable {
    public let bondingDeposits: [EarnBondingDeposits]
    public let unbondingWithdrawals: [EarnUnbondingWithdrawals]

    public var isEmpty: Bool {
        bondingDeposits.isEmpty && unbondingWithdrawals.isEmpty
    }
}

public struct EarnBondingUnbondingRequests: Equatable, Hashable {
    public enum RequestType: Equatable {
        case bonding
        case unbonding
    }

    public let type: RequestType
    public let product: String
    public let currency: String
    public let userId: String
    /// bonding or unbonding days
    public let daysLeft: Int
    /// bonding or unbonding start date
    public let startDate: Date?
    /// bonding or unbonding expiry date
    public let expiryDate: Date?
    public let amount: MoneyValue?

    public init(bonding: EarnBondingDeposits) {
        self.type = .bonding
        self.product = bonding.product
        self.currency = bonding.currency
        self.userId = bonding.userId
        self.daysLeft = bonding.bondingDays
        self.startDate = bonding.bondingStartDate
        self.expiryDate = bonding.bondingExpiryDate
        self.amount = bonding.amount
    }

    public init(unbonding: EarnUnbondingWithdrawals) {
        self.type = .unbonding
        self.product = unbonding.product
        self.currency = unbonding.currency
        self.userId = unbonding.userId
        self.daysLeft = unbonding.unbondingDays
        self.startDate = unbonding.unbondingStartDate
        self.expiryDate = unbonding.unbondingExpiryDate
        self.amount = unbonding.amount
    }
}

public struct EarnUnbondingWithdrawals: Decodable {
    public let product: String
    public let currency: String
    public let userId: String
    public let unbondingDays: Int
    public let unbondingStartDate: Date?
    public let unbondingExpiryDate: Date?
    public let amount: MoneyValue?

    enum CodingKeys: CodingKey {
        case product
        case currency
        case userId
        case unbondingDays
        case unbondingStartDate
        case unbondingExpiryDate
        case isCustodialTransfer
        case amount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.product = try container.decode(String.self, forKey: .product)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.unbondingDays = try container.decode(Int.self, forKey: .unbondingDays)
        self.amount = try? MoneyValue(from: decoder)

        self.unbondingStartDate = DateFormatter
            .iso8601Format
            .date(
                from: (try? container.decodeIfPresent(String.self, forKey: .unbondingStartDate)) ?? ""
            )

        self.unbondingExpiryDate = DateFormatter
            .iso8601Format
            .date(
                from: (try? container.decodeIfPresent(String.self, forKey: .unbondingExpiryDate)) ?? ""
            )
    }
}

public struct EarnBondingDeposits: Decodable {
    public let product: String
    public let currency: String
    public let userId: String
    public let bondingDays: Int
    public let bondingStartDate: Date?
    public let bondingExpiryDate: Date?
    public let amount: MoneyValue?

    enum CodingKeys: CodingKey {
        case product
        case currency
        case userId
        case bondingDays
        case bondingStartDate
        case bondingExpiryDate
        case isCustodialTransfer
        case amount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.product = try container.decode(String.self, forKey: .product)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.bondingDays = try container.decode(Int.self, forKey: .bondingDays)
        self.amount = try? MoneyValue(from: decoder)

        self.bondingStartDate = DateFormatter
            .iso8601Format
            .date(
                from: (try? container.decodeIfPresent(String.self, forKey: .bondingStartDate)) ?? ""
            )

        self.bondingExpiryDate = DateFormatter
            .iso8601Format
            .date(
                from: (try? container.decodeIfPresent(String.self, forKey: .bondingExpiryDate)) ?? ""
            )
    }
}

public struct EarnWithdrawalPendingRequest {

    public init(
        currency: String,
        product: String,
        userId: String,
        amount: MoneyValue? = nil,
        maxRequested: Bool? = nil,
        unbondingStartDate: Date? = nil,
        unbondingExpiry: Date? = nil
    ) {
        self.currency = currency
        self.product = product
        self.userId = userId
        self.amount = amount
        self.maxRequested = maxRequested
        self.unbondingStartDate = unbondingStartDate
        self.unbondingExpiry = unbondingExpiry
    }

    public let currency: String
    public let product: String
    public let userId: String
    public let maxRequested: Bool?
    public let amount: MoneyValue?
    public let unbondingStartDate: Date?
    public let unbondingExpiry: Date?
}

extension EarnWithdrawalPendingRequest: Decodable {

    enum CodingKeys: String, CodingKey {
        case currency
        case product
        case userId
        case maxRequested
        case amount
        case unbondingStartDate
        case unbondingExpiry
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.currency = try container.decode(String.self, forKey: .currency)
        self.product = try container.decode(String.self, forKey: .product)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.maxRequested = try? container.decodeIfPresent(Bool.self, forKey: .maxRequested)
        self.amount = try? MoneyValue(from: decoder)

        self.unbondingStartDate = DateFormatter
            .iso8601Format
            .date(
                from: (try? container.decodeIfPresent(String.self, forKey: .unbondingStartDate)) ?? ""
            )

        self.unbondingExpiry = DateFormatter
            .iso8601Format
            .date(
                from: (try? container.decodeIfPresent(String.self, forKey: .unbondingExpiry)) ?? ""
            )
    }
}

public struct EarnRate: Hashable, Decodable {

    public init(commission: Double? = nil, triggerPrice: String? = nil, rate: Double) {
        self.commission = commission
        self.triggerPrice = triggerPrice
        self.rate = rate
    }

    public var commission: Double?
    public var triggerPrice: String?
    public var rate: Double
}

// earn/limits

public typealias EarnLimits = [String: EarnCurrencyLimit]
public struct EarnCurrencyLimit: Hashable, Decodable {
    public var minDepositValue: String?
    public var minDepositAmount: String?
    public var maxWithdrawalAmount: String?
    public var lockUpDuration: Int?
    public var bondingDays: Int?
    public var unbondingDays: Int?
    public var disabledWithdrawals: Bool?
    public var rewardFrequency: String?
}

// payments/accounts/(staking|savings)

public struct EarnAddress: Hashable, Decodable {
    public let accountRef: String
}

// accounts/(staking|savings)

public typealias EarnAccounts = [String: EarnAccount]
public struct EarnAccount: Hashable, Decodable {
    public var balance: CryptoValue?
    public var pendingDeposit: CryptoValue?
    public var pendingWithdrawal: CryptoValue?
    public var totalRewards: CryptoValue?
    public var pendingRewards: CryptoValue?
    public var bondingDeposits: CryptoValue?
    public var unbondingWithdrawals: CryptoValue?
    public var locked: CryptoValue?
    public var earningBalance: CryptoValue?
}

extension EarnAccount {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        guard let currency = decoder.codingPath.last.flatMap({ CryptoCurrency(code: $0.stringValue) }) else {
            throw DecodingError.typeMismatch(
                Self.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected to decode a currency container [String: EarnAccount]"
                )
            )
        }
        self.balance = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "balance").or("0"), currency: currency)
        self.pendingDeposit = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "pendingDeposit").or("0"), currency: currency)
        self.pendingWithdrawal = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "pendingWithdrawal").or("0"), currency: currency)
        self.totalRewards = try CryptoValue.create(
            minor: container.decodeIfPresent(String.self, forKey: "totalRewards").or(container.decodeIfPresent(String.self, forKey: "totalInterest").or("0")),
            currency: currency
        )
        self.pendingRewards = try CryptoValue.create(
            minor: container.decodeIfPresent(String.self, forKey: "pendingRewards").or(container.decodeIfPresent(String.self, forKey: "pendingInterest").or("0")),
            currency: currency
        )
        self.bondingDeposits = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "bondingDeposits").or("0"), currency: currency)
        self.unbondingWithdrawals = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "unbondingWithdrawals").or("0"), currency: currency)
        self.locked = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "locked").or("0"), currency: currency)
        self.earningBalance = try CryptoValue.create(minor: container.decodeIfPresent(String.self, forKey: "earningBalance").or("0"), currency: currency)
    }
}

public struct EarnActivityList: Hashable, Decodable {
    public let items: [EarnActivity]
}

public struct EarnActivity: Hashable, Codable {

    public struct State: NewTypeString {
        public var value: String
        public init(_ value: String) { self.value = value }
    }

    public struct ActivityType: NewTypeString {
        public var value: String
        public init(_ value: String) { self.value = value }
    }

    public struct ExtraAttributes: Hashable, Codable {

        public struct Beneficiary: Hashable, Codable {
            public let user: String
            public let accountRef: String
        }

        public let address: String?
        public let confirmations: Int?
        public let hash: String?
        public let identifier: String?
        public let transactionHash: String?
        public let transferType: String?
        public let beneficiary: Beneficiary?

        public var isInternalTransfer: Bool {
            guard let type = transferType else { return false }
            return type == "INTERNAL"
        }
    }

    public struct Amount: Hashable, Codable {
        public let symbol: String
        public let value: String
    }

    public let amount: Amount
    public let amountMinor: String
    public let extraAttributes: ExtraAttributes?
    public let id: String
    public let insertedAt: String
    public let state: State
    public let type: ActivityType

    public var currency: CurrencyType {
        try! CurrencyType(code: amount.symbol)
    }

    public var value: MoneyValue {
        MoneyValue.create(minor: amountMinor, currency: currency) ?? .zero(currency: currency)
    }

    public var date: (insertedAt: Date, ()) {
        (My.iso8601Format.date(from: insertedAt) ?? Date.distantPast, ())
    }

    private static let iso8601Format: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension EarnActivity.State {
    public static let failed: Self = "FAILED"
    public static let rejected: Self = "REJECTED"
    public static let processing: Self = "PROCESSING"
    public static let created: Self = "CREATED"
    public static let complete: Self = "COMPLETE"
    public static let pending: Self = "PENDING"
    public static let manualReview: Self = "MANUAL_REVIEW"
    public static let cleared: Self = "CLEARED"
    public static let refunded: Self = "REFUNDED"
    public static let fraudReview: Self = "FRAUD_REVIEW"
    public static let unknown: Self = "UNKNOWN"
}

extension EarnActivity.ActivityType {
    public static let deposit: Self = "DEPOSIT"
    public static let withdraw: Self = "WITHDRAWAL"
    public static let interestEarned: Self = "INTEREST_OUTGOING"
    public static let debit: Self = "DEBIT"
}

public struct EarnModel: Decodable, Hashable {

    public init(
        rates: EarnModel.Rates,
        account: EarnModel.Account,
        limit: EarnModel.Limit,
        activity: [EarnActivity]
    ) {
        self.rates = rates
        self.account = account
        self.limit = limit
        self.activity = activity
    }

    public let rates: Rates
    public let account: Account
    public let limit: Limit
    public let activity: [EarnActivity]

    public var currency: CryptoCurrency {
        account.balance.currency.cryptoCurrency!
    }
}

extension EarnModel {

    public typealias Rates = EarnRate

    public struct Account: Decodable, Hashable {

        public init(
            balance: MoneyValue,
            bonding: EarnModel.Account.Bonding,
            locked: MoneyValue,
            pending: EarnModel.Account.Pending,
            total: EarnModel.Account.Total,
            unbonding: EarnModel.Account.Unbonding
        ) {
            self.balance = balance
            self.bonding = bonding
            self.locked = locked
            self.pending = pending
            self.total = total
            self.unbonding = unbonding
        }

        public struct Bonding: Decodable, Hashable {

            public init(deposits: MoneyValue) {
                self.deposits = deposits
            }

            public let deposits: MoneyValue
        }

        public struct Pending: Decodable, Hashable {

            public init(deposit: MoneyValue, withdrawal: MoneyValue) {
                self.deposit = deposit
                self.withdrawal = withdrawal
            }

            public let deposit: MoneyValue
            public let withdrawal: MoneyValue
        }

        public struct Total: Decodable, Hashable {

            public init(rewards: MoneyValue) {
                self.rewards = rewards
            }

            public let rewards: MoneyValue
        }

        public struct Unbonding: Decodable, Hashable {

            public init(withdrawals: MoneyValue) {
                self.withdrawals = withdrawals
            }

            public let withdrawals: MoneyValue
        }

        public let balance: MoneyValue
        public let bonding: Bonding
        public let locked: MoneyValue
        public let pending: Pending
        public let total: Total
        public let unbonding: Unbonding
    }

    public struct Limit: Decodable, Hashable {

        public init(days: Days, withdraw: Withdraw, reward: Reward) {
            self.days = days
            self.withdraw = withdraw
            self.reward = reward
        }

        public struct Reward: Decodable, Hashable {

            public init(frequency: Tag?) {
                self.frequency = frequency
            }

            public let frequency: Tag?
        }

        public struct Days: Decodable, Hashable {

            public init(bonding: Int, unbonding: Int) {
                self.bonding = bonding
                self.unbonding = unbonding
            }

            public let bonding: Int
            public let unbonding: Int
        }

        public struct Withdraw: Decodable, Hashable {

            public init(is: EarnModel.Limit.Withdraw.Is) {
                self.is = `is`
            }

            public let `is`: Is; public struct Is: Decodable, Hashable {

                public init(disabled: Bool) {
                    self.disabled = disabled
                }

                public let disabled: Bool
            }
        }

        public let days: Days
        public let withdraw: Withdraw
        public let reward: Reward
    }
}
