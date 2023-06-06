// Copyright © Blockchain Luxembourg S.A. All rights reserved.

@testable import BlockchainApp
import BlockchainNamespace
import Combine
import DIKit
import NetworkKit
@testable import RemoteNotificationsKit
import XCTest

final class RemoteNotificationServiceTests: XCTestCase {

    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = []
    }

    override func tearDownWithError() throws {
        cancellables = []
        try super.tearDownWithError()
    }

    // MARK: - Happy Scenarios using mocks

    func testRegistrationAndTokenSendingAreSuccessfulUsingMockServices() {
        let service: RemoteNotificationTokenSending = RemoteNotificationService(
            authorizer: MockRemoteNotificationAuthorizer(
                expectedAuthorizationStatus: .authorized,
                authorizationRequestExpectedStatus: .success(())
            ),
            notificationRelay: MockRemoteNotificationRelay(),
            backgroundReceiver: resolve(),
            externalService: MockExternalNotificationServiceProvider(
                expectedTokenResult: .success("firebase-token-value"),
                expectedTopicSubscriptionResult: .success(())
            ),
            iterableService: MockIterableService(),
            networkService: MockRemoteNotificationNetworkService(expectedResult: .success(())),
            sharedKeyRepository: MockGuidSharedKeyRepositoryAPI(),
            guidRepository: MockGuidSharedKeyRepositoryAPI()
        )
        let registerExpectation = expectation(
            description: "Service registered token."
        )
        service.sendTokenIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        XCTFail("Expected success. Got \(error) instead")
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    registerExpectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(
            for: [
                registerExpectation
            ],
            timeout: 10.0
        )
    }

    // MARK: - Unauthorized permission

    func testTokenSendWithUnauthorizedPermissionsUsingMockServices() {
        let service: RemoteNotificationTokenSending = RemoteNotificationService(
            authorizer: MockRemoteNotificationAuthorizer(
                expectedAuthorizationStatus: .denied,
                authorizationRequestExpectedStatus: .success(())
            ),
            notificationRelay: MockRemoteNotificationRelay(),
            backgroundReceiver: resolve(),
            externalService: MockExternalNotificationServiceProvider(
                expectedTokenResult: .success("firebase-token-value"),
                expectedTopicSubscriptionResult: .success(())
            ),
            iterableService: MockIterableService(),
            networkService: MockRemoteNotificationNetworkService(expectedResult: .success(())),
            sharedKeyRepository: MockGuidSharedKeyRepositoryAPI(),
            guidRepository: MockGuidSharedKeyRepositoryAPI()
        )

        let registerExpectation = expectation(
            description: "Service registered token."
        )
        service.sendTokenIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure:
                        registerExpectation.fulfill()
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    XCTFail("Expected permission authorization. Got success instead")
                }
            )
            .store(in: &cancellables)

        wait(
            for: [
                registerExpectation
            ],
            timeout: 10.0
        )
    }

    // MARK: - Unauthorized permission

    func testTokenSendWithExternalServiceFetchingFailure() {
        let service: RemoteNotificationTokenSending = RemoteNotificationService(
            authorizer: MockRemoteNotificationAuthorizer(
                expectedAuthorizationStatus: .authorized,
                authorizationRequestExpectedStatus: .success(())
            ),
            notificationRelay: MockRemoteNotificationRelay(),
            backgroundReceiver: resolve(),
            externalService: MockExternalNotificationServiceProvider(
                expectedTokenResult: .failure(.tokenIsEmpty),
                expectedTopicSubscriptionResult: .success(())
            ),
            iterableService: MockIterableService(),
            networkService: MockRemoteNotificationNetworkService(expectedResult: .success(())),
            sharedKeyRepository: MockGuidSharedKeyRepositoryAPI(),
            guidRepository: MockGuidSharedKeyRepositoryAPI()
        )

        let registerExpectation = expectation(
            description: "Service registered token."
        )
        service.sendTokenIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure:
                        registerExpectation.fulfill()
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    XCTFail("Expected failure fetching the token. Got success instead")
                }
            )
            .store(in: &cancellables)

        wait(
            for: [
                registerExpectation
            ],
            timeout: 10.0
        )
    }

    // MARK: - Unauthorized permission

    func testTokenSendWithNetworkServiceFailure() {
        let service: RemoteNotificationTokenSending = RemoteNotificationService(
            authorizer: MockRemoteNotificationAuthorizer(
                expectedAuthorizationStatus: .authorized,
                authorizationRequestExpectedStatus: .success(())
            ),
            notificationRelay: MockRemoteNotificationRelay(),
            backgroundReceiver: resolve(),
            externalService: MockExternalNotificationServiceProvider(
                expectedTokenResult: .success("firebase-token-value"),
                expectedTopicSubscriptionResult: .success(())
            ),
            iterableService: MockIterableService(),
            networkService: MockRemoteNotificationNetworkService(expectedResult: .failure(.registrationFailure)),
            sharedKeyRepository: MockGuidSharedKeyRepositoryAPI(),
            guidRepository: MockGuidSharedKeyRepositoryAPI()
        )

        let registerExpectation = expectation(
            description: "Service registered token."
        )
        service.sendTokenIfNeeded()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure:
                        registerExpectation.fulfill()
                    case .finished:
                        break
                    }
                },
                receiveValue: { _ in
                    XCTFail("Expected failure sending the token. Got success instead")
                }
            )
            .store(in: &cancellables)

        wait(
            for: [
                registerExpectation
            ],
            timeout: 10.0
        )
    }
}
