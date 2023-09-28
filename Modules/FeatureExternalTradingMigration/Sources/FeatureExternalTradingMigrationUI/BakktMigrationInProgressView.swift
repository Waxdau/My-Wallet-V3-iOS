// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainUI
import SwiftUI

struct BakktMigrationInProgressView: View {
    @Dependency(\.app) var app
    typealias L10n = LocalizationConstants.ExternalTradingMigration.MigrationInProgress
    var onDone: () -> Void

    var body: some View {
        VStack {
            Image(
                "blockchain_logo",
                bundle: Bundle.featureExternalTradingMigration
            )
            .frame(width: 88)

            VStack(spacing: Spacing.padding1) {
                Text(L10n.headerTitle)
                    .typography(.title3)
                    .foregroundColor(.semantic.title)

                Text(L10n.headerDescription)
                    .typography(.body1)
                    .foregroundColor(.semantic.body)
                    .multilineTextAlignment(.center)
            }
            Spacer()

            PrimaryButton(title: L10n.goToDashboard) {
                onDone()
            }
        }
        .padding(.top, Spacing.padding2)
        .padding(.horizontal, Spacing.padding2)
    }
}


struct BakktMigrationInProgressView_Preview: PreviewProvider {
    static var previews: some View {
        BakktMigrationInProgressView(onDone: {})
    }
}
