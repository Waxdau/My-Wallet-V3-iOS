// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import BlockchainNamespace
import ComposableArchitecture
import FeatureDashboardDomain
import Foundation
import SwiftUI
import UnifiedActivityDomain

public struct DashboardActivityRow: Reducer {
    public let app: AppProtocol
    public init(
        app: AppProtocol
    ) {
        self.app = app
    }

    public enum Action: Equatable {}

    public struct State: Equatable, Identifiable {
        public var id: String {
            "\(activity.network)/\(activity.hashValue)"
        }

        var activity: ActivityEntry
        var isLastRow: Bool

        public init(
            isLastRow: Bool,
            activity: ActivityEntry
        ) {
            self.activity = activity
            self.isLastRow = isLastRow
        }
    }

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
