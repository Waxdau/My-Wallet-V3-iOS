// Copyright © Blockchain Luxembourg S.A. All rights reserved.

import Blockchain
import Errors
import FeatureAnnouncementsDomain
import Foundation
import NetworkKit
import ToolKit

final class AnnouncementsClient: AnnouncementsClientAPI {

    private static let platform = "iOS"

    // MARK: - Types

    enum GetMessagesParameters: String {
        case email
        case count
        case SDKVersion
        case platform
        case packageName

        static func parameters(_ email: String) -> [URLQueryItem] {
            [
                URLQueryItem(name: Self.email.rawValue, value: email),
                URLQueryItem(name: count.rawValue, value: "100"),
                URLQueryItem(name: platform.rawValue, value: AnnouncementsClient.platform),
                URLQueryItem(name: packageName.rawValue, value: Bundle.main.bundleIdentifier)
            ]
        }
    }

    struct EventParameters: Encodable {

        struct DeviceInfo: Encodable {
            let deviceId: String
            let platform = AnnouncementsClient.platform
            let appPackageName = Bundle.main.bundleIdentifier
        }

        let email: String?
        let messageId: String
        let deviceInfo: DeviceInfo

        let clickedUrl: String?
        let deleteAction: Announcement.Action?
    }

    struct GetMessagesPayload: Decodable {
        let inAppMessages: [Announcement]
    }

    private enum Path {
        static let getMessages = ["inApp", "getMessages"]
        static let view = ["events", "trackInAppOpen"]
        static let tap = ["events", "trackInAppClick"]
        static let consume = ["events", "inAppConsume"]
    }

    // MARK: - Properties

    private let emailProvider: AnnouncementsEmailProviderAPI
    private let networkAdapter: NetworkAdapterAPI
    private let requestBuilder: RequestBuilder
    private let deviceInfo: DeviceInfo

    // MARK: - Setup

    init(
        deviceInfo: DeviceInfo,
        networkAdapter: NetworkAdapterAPI,
        requestBuilder: RequestBuilder,
        emailProvider: AnnouncementsEmailProviderAPI
    ) {
        self.deviceInfo = deviceInfo
        self.networkAdapter = networkAdapter
        self.requestBuilder = requestBuilder
        self.emailProvider = emailProvider
    }

    func fetchMessages() -> AnyPublisher<[Announcement], NabuNetworkError> {
        emailProvider.email
            .flatMap { [requestBuilder, networkAdapter] email -> AnyPublisher<[Announcement], NabuNetworkError> in
                let request = requestBuilder.get(
                    path: Path.getMessages,
                    parameters: GetMessagesParameters.parameters(email)
                )!

                return networkAdapter
                    .perform(request: request, responseType: GetMessagesPayload.self)
                    .map(\.inAppMessages)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    func setRead(announcement: Announcement) -> AnyPublisher<Void, NabuNetworkError> {
        emailProvider.email
            .flatMap { [weak self] email -> AnyPublisher<Void, NabuNetworkError> in
                guard let self else {
                    return .empty()
                }
                return sendEvent(
                    path: Path.view,
                    email: email,
                    messageId: announcement.id
                )
            }
            .eraseToAnyPublisher()
    }

    func setTapped(announcement: Announcement) -> AnyPublisher<Void, NabuNetworkError> {
        emailProvider.email
            .flatMap { [weak self] email -> AnyPublisher<Void, NabuNetworkError> in
                guard let self else {
                    return .empty()
                }
                return sendEvent(
                    path: Path.tap,
                    email: email,
                    messageId: announcement.id,
                    clickedUrl: announcement.content.actionUrl
                )
            }
            .eraseToAnyPublisher()
    }

    func setDismissed(
        _ announcement: Announcement,
        with action: Announcement.Action
    ) -> AnyPublisher<Void, NabuNetworkError> {
        emailProvider.email
            .flatMap { [weak self] email -> AnyPublisher<Void, NabuNetworkError> in
                guard let self else {
                    return .empty()
                }
                return sendEvent(
                    path: Path.consume,
                    email: email,
                    messageId: announcement.id,
                    deleteAction: action
                )
            }
            .eraseToAnyPublisher()
    }

    private func sendEvent(
        path: [String],
        email: String,
        messageId: String,
        clickedUrl: String? = nil,
        deleteAction: Announcement.Action? = nil
    ) -> AnyPublisher<Void, NabuNetworkError> {
        let request = requestBuilder.post(
            path: path,
            body: try? EventParameters(
                email: email,
                messageId: messageId,
                deviceInfo: EventParameters.DeviceInfo(deviceId: deviceInfo.uuidString),
                clickedUrl: clickedUrl,
                deleteAction: deleteAction
            ).encode()
        )!

        return networkAdapter.perform(request: request)
    }
}
