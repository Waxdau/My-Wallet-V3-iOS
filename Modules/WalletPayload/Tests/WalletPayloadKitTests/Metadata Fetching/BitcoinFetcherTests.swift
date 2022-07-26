// Copyright © Blockchain Luxembourg S.A. All rights reserved.

@testable import MetadataKit
@testable import MetadataKitMock
@testable import WalletPayloadDataKit
@testable import WalletPayloadKit
@testable import WalletPayloadKitMock

import Combine
import TestKit
import ToolKit
import XCTest

class BitcoinFetcherTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    let walletV4 = Fixtures.loadJSONData(filename: "wallet.v4", in: .module)!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    func test_fetches_an_entry_correctly() throws {
        let metadataServiceMock = MetadataServiceMock()

        let walletHolder = WalletHolder()
        let response = try JSONDecoder().decode(WalletResponse.self, from: walletV4)
        let nativeWallet = NativeWallet.from(blockchainWallet: response)
        let wrapper = Wrapper(walletPayload: WalletPayload.empty, wallet: nativeWallet)
        walletHolder.hold(walletState: .loaded(wrapper: wrapper, metadata: MetadataState.mock))
            .subscribe()
            .store(in: &cancellables)

        let btcFetcher = BitcoinEntryFetcher(
            walletHolder: walletHolder,
            metadataEntryService: metadataServiceMock
        )

        let entryPayload = BitcoinEntryPayload()
        metadataServiceMock.fetchEntryResult = .success(
            entryPayload
        )

        let expectedEntry = BitcoinEntry(
            payload: entryPayload,
            wallet: nativeWallet
        )

        let expectation = expectation(description: "should fetch bitcoin")

        btcFetcher.fetchOrCreateBitcoin()
            .sink(
                receiveCompletion: { completion in
                    guard case .failure = completion else {
                        return
                    }
                    XCTFail("should provide correct value")
                },
                receiveValue: { value in
                    XCTAssertTrue(metadataServiceMock.fetchEntryCalled)
                    XCTAssertEqual(value, expectedEntry)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 10)
    }

    func test_saves_an_entry_if_not_created() throws {
        let metadataServiceMock = MetadataServiceMock()

        let walletHolder = WalletHolder()
        let response = try JSONDecoder().decode(WalletResponse.self, from: walletV4)
        let nativeWallet = NativeWallet.from(blockchainWallet: response)
        let wrapper = Wrapper(walletPayload: WalletPayload.empty, wallet: nativeWallet)
        walletHolder.hold(walletState: .loaded(wrapper: wrapper, metadata: MetadataState.mock))
            .subscribe()
            .store(in: &cancellables)

        let btcFetcher = BitcoinEntryFetcher(
            walletHolder: walletHolder,
            metadataEntryService: metadataServiceMock
        )

        let entryPayload = BitcoinEntryPayload()
        metadataServiceMock.fetchEntryResult = .failure(.fetchFailed(.loadMetadataError(.notYetCreated)))
        metadataServiceMock.saveEntryResult = .success(.noValue)

        let expectedEntry = BitcoinEntry(
            payload: entryPayload,
            wallet: nativeWallet
        )

        let expectation = expectation(description: "should fetch bitcoin")

        btcFetcher.fetchOrCreateBitcoin()
            .sink(
                receiveCompletion: { completion in
                    guard case .failure = completion else {
                        return
                    }
                    XCTFail("should provide correct value")
                },
                receiveValue: { value in
                    XCTAssertTrue(metadataServiceMock.fetchEntryCalled)
                    XCTAssertTrue(metadataServiceMock.saveEntryCalled)
                    XCTAssertEqual(value, expectedEntry)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 10)
    }
}

/// Specific mock class for `EthereumEntryPayload`
private final class MetadataServiceMock: WalletMetadataEntryServiceAPI {

    var fetchEntryCalled: Bool = false
    var fetchEntryResult = Result<BitcoinEntryPayload, WalletAssetFetchError>.failure(.notInitialized)

    func fetchEntry<Entry: MetadataNodeEntry>(type: Entry.Type) -> AnyPublisher<Entry, WalletAssetFetchError> {
        fetchEntryCalled = true
        return fetchEntryResult.map { $0 as! Entry }.publisher
            .eraseToAnyPublisher()
    }

    var saveEntryCalled: Bool = false
    var saveEntryResult: Result<EmptyValue, WalletAssetSaveError> = .failure(.notInitialized)

    func save<Node: MetadataNodeEntry>(node: Node) -> AnyPublisher<EmptyValue, WalletAssetSaveError> {
        saveEntryCalled = true
        return saveEntryResult.publisher.eraseToAnyPublisher()
    }
}
