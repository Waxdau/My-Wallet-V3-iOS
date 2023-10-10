// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import ComposableArchitecture
import FeatureDashboardDomain
import FeatureProductsDomain
import Foundation
import Localization
import PlatformKit

public struct DashboardAnnouncementsSection: Reducer {
    enum ViewState {
        case idle
        case empty
        case data
    }

    public let app: AppProtocol
    public let recoverPhraseProviding: RecoveryPhraseStatusProviding

    private typealias L10n = LocalizationConstants.Dashboard.Announcements

    public init(
        app: AppProtocol,
        recoverPhraseProviding: RecoveryPhraseStatusProviding
    ) {
        self.app = app
        self.recoverPhraseProviding = recoverPhraseProviding
    }

    public enum Action: Equatable {
        case onAppear
        case onDashboardAnnouncementFetched(Result<[DashboardAnnouncement], Never>)
        case onAnnouncementTapped (
            id: DashboardAnnouncementRow.State.ID,
            action: DashboardAnnouncementRow.Action
        )
    }

    public struct State: Equatable {
        var viewState: ViewState = .idle
        var announcementsCards: IdentifiedArrayOf<DashboardAnnouncementRow.State>
        var isEmpty: Bool {
            announcementsCards.isEmpty
        }

        public init(announcementsCards: IdentifiedArrayOf<DashboardAnnouncementRow.State> = []) {
            self.announcementsCards = announcementsCards
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .publisher {
                    recoverPhraseProviding
                        .isRecoveryPhraseVerified
                        .combineLatest(
                            app
                                .publisher(
                                    for: blockchain.app.is.DeFi.only,
                                    as: Bool.self
                                )
                                .compactMap(\.value)
                        )
                        .receive(on: DispatchQueue.main)
                        .map { backedUp, isDeFiOnly in
                            if backedUp == false {
                                let tag = blockchain.ux.home.dashboard.announcement.backup.seed.phrase
                                let result = Result<[DashboardAnnouncement], Never>.success(
                                    [
                                        DashboardAnnouncement(
                                            id: UUID().uuidString,
                                            title: isDeFiOnly ? L10n.DeFiOnly.title : L10n.recoveryPhraseBackupTitle,
                                            message: isDeFiOnly ? L10n.DeFiOnly.message : L10n.recoveryPhraseBackupMessage,
                                            action: tag
                                        )
                                    ]
                                )
                                return .onDashboardAnnouncementFetched(result)
                            } else {
                                return .onDashboardAnnouncementFetched(.success([]))
                            }
                        }
                }

            case .onAnnouncementTapped:
                return .none

            case .onDashboardAnnouncementFetched(.success(let announcements)):
                guard announcements.isNotEmpty else {
                    state.viewState = .empty
                    return .none
                }
                let items = announcements
                    .map {
                        DashboardAnnouncementRow.State(
                            announcement: $0
                        )
                    }
                state.viewState = .data
                state.announcementsCards = IdentifiedArrayOf(uniqueElements: items)
                return .none
            }
        }
        .forEach(\.announcementsCards, action: /Action.onAnnouncementTapped) {
            DashboardAnnouncementRow(app: app)
        }
    }
}
