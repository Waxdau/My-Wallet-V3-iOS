import BlockchainUI
import FeatureAppUI
import FeatureStakingUI

@MainActor
struct SiteMap {

    let app: AppProtocol

    @ViewBuilder func view(
        for ref: Tag.Reference,
        in context: Tag.Context = [:]
    ) throws -> some View {
        let story = try ref.tag.as(blockchain.ux.type.story)
        switch ref.tag {
        case blockchain.ux.user.portfolio:
            PortfolioView()
        case blockchain.ux.prices:
            PricesView()
        case blockchain.ux.user.rewards:
            RewardsView()
        case blockchain.ux.user.activity:
            ActivityView()
        case blockchain.ux.asset:
            let currency = try ref.context[blockchain.ux.asset.id].decode(CryptoCurrency.self)
            CoinAdapterView(
                cryptoCurrency: currency,
                dismiss: {
                    app.post(value: true, of: story.article.plain.navigation.bar.button.close.tap.then.close.key(to: ref.context))
                }
            )
        case isDescendant(of: blockchain.ux.transaction):
            try transaction(for: ref, in: context)
        default:
            throw Error(message: "No view", tag: ref, context: context)
        }
    }
}

extension SiteMap {

    @ViewBuilder func transaction(
        for ref: Tag.Reference,
        in context: Tag.Context = [:]
    ) throws -> some View {
        switch ref.tag {
        case blockchain.ux.transaction.disclaimer:
            StakingConsiderationsView()
                .context([blockchain.user.earn.product.id: "staking"])
        default:
            throw Error(message: "No view", tag: ref, context: context)
        }
    }
}

extension SiteMap {

    struct Error: Swift.Error {
        let message: String
        let tag: Tag.Reference
        let context: Tag.Context
    }
}
