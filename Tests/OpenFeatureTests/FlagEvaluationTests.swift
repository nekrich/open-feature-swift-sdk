import Foundation
import XCTest
import Combine

@testable import OpenFeature

final class FlagEvaluationTests: XCTestCase {
    func testSingletonPersists() {
        XCTAssertTrue(OpenFeatureAPI.shared === OpenFeatureAPI.shared)
    }

    func testApiSetsProvider() {
        let provider = NoOpProvider()
        OpenFeatureAPI.shared.setProvider(provider: provider)
        XCTAssertTrue((OpenFeatureAPI.shared.getProvider() as? NoOpProvider) === provider)
    }

    func testProviderMetadata() {
        OpenFeatureAPI.shared.setProvider(provider: DoSomethingProvider())

        XCTAssertEqual(OpenFeatureAPI.shared.getProviderMetadata()?.name, DoSomethingProvider.name)
    }

    func testHooksPersist() {
        let hook1 = BooleanHookMock()
        let hook2 = BooleanHookMock()

        OpenFeatureAPI.shared.addHooks(hooks: hook1)

        XCTAssertEqual(OpenFeatureAPI.shared.hooks.count, 1)

        OpenFeatureAPI.shared.addHooks(hooks: hook2)
        XCTAssertEqual(OpenFeatureAPI.shared.hooks.count, 2)
    }

    func testNamedClient() {
        let client = OpenFeatureAPI.shared.getClient(name: "test", version: nil)
        XCTAssertEqual((client as? OpenFeatureClient)?.name, "test")
    }

    func testClientHooksPersist() {
        let hook1 = BooleanHookMock()
        let hook2 = BooleanHookMock()

        let client = OpenFeatureAPI.shared.getClient()
        client.addHooks(hook1)

        XCTAssertEqual(client.hooks.count, 1)

        client.addHooks(hook2)
        XCTAssertEqual(client.hooks.count, 2)
    }

    func testSimpleFlagEvaluation() {
        let provider = DoSomethingProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        let staleExpectation = XCTestExpectation(description: "Stale")
        let eventState = provider.observe().sink { event in
            switch event {
            case ProviderEvent.ready:
                readyExpectation.fulfill()
            case ProviderEvent.error:
                errorExpectation.fulfill()
            case ProviderEvent.stale:
                staleExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }

        wait(for: [staleExpectation], timeout: 5)
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)
        let client = OpenFeatureAPI.shared.getClient()
        let key = "key"
        XCTAssertEqual(client.getValue(key: key, defaultValue: false), true)
        XCTAssertEqual(client.getValue(key: key, defaultValue: false), true)
        XCTAssertEqual(
            client.getValue(
                key: key, defaultValue: false, options: FlagEvaluationOptions()), true)

        XCTAssertEqual(client.getValue(key: key, defaultValue: "test"), "tset")
        XCTAssertEqual(client.getValue(key: key, defaultValue: "test"), "tset")
        XCTAssertEqual(
            client.getValue(
                key: key, defaultValue: "test", options: FlagEvaluationOptions()), "tset")

        XCTAssertEqual(client.getValue(key: key, defaultValue: 4), 400)
        XCTAssertEqual(client.getValue(key: key, defaultValue: 4), 400)
        XCTAssertEqual(
            client.getValue(key: key, defaultValue: 4, options: FlagEvaluationOptions()),
            400)

        XCTAssertEqual(client.getValue(key: key, defaultValue: 0.4), 40.0)
        XCTAssertEqual(client.getValue(key: key, defaultValue: 0.4), 40.0)
        XCTAssertEqual(
            client.getValue(key: key, defaultValue: 0.4, options: FlagEvaluationOptions()),
            40.0)

        var value: Value = client.getValue(key: key, defaultValue: .structure([:]))
        XCTAssertEqual(value, .null)
        value = client.getValue(key: key, defaultValue: .structure([:]))
        XCTAssertEqual(value, .null)
        value = client.getValue(key: key, defaultValue: .structure([:]), options: FlagEvaluationOptions())
        XCTAssertEqual(value, .null)
        XCTAssertNotNil(eventState)
    }

    func testDetailedFlagEvaluation() async {
        let provider = DoSomethingProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        let staleExpectation = XCTestExpectation(description: "Stale")
        let eventState = provider.observe().sink { event in
            switch event {
            case ProviderEvent.ready:
                readyExpectation.fulfill()
            case ProviderEvent.error:
                errorExpectation.fulfill()
            case ProviderEvent.stale:
                staleExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }

        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)
        let client = OpenFeatureAPI.shared.getClient()
        let key = "key"
        let booleanDetails = FlagEvaluationDetails(flagKey: key, value: true, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: false), booleanDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: false), booleanDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: false, options: FlagEvaluationOptions()), booleanDetails)

        let stringDetails = FlagEvaluationDetails(flagKey: key, value: "tset", variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: "test"), stringDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: "test"), stringDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: "test", options: FlagEvaluationOptions()), stringDetails)

        let integerDetails = FlagEvaluationDetails(flagKey: key, value: Int64(400), variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 4), integerDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 4), integerDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: 4, options: FlagEvaluationOptions()), integerDetails)

        let doubleDetails = FlagEvaluationDetails(flagKey: key, value: 40.0, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 0.4), doubleDetails)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: 0.4), doubleDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: 0.4, options: FlagEvaluationOptions()), doubleDetails)

        let objectDetails = FlagEvaluationDetails(flagKey: key, value: Value.null, variant: nil)
        XCTAssertEqual(client.getDetails(key: key, defaultValue: .structure([:])), objectDetails)
        XCTAssertEqual(
            client.getDetails(key: key, defaultValue: .structure([:])), objectDetails)
        XCTAssertEqual(
            client.getDetails(
                key: key, defaultValue: .structure([:]), options: FlagEvaluationOptions()),
            objectDetails)
        XCTAssertNotNil(eventState)
    }

    func testHooksAreFired() async {
        let provider = NoOpProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        let staleExpectation = XCTestExpectation(description: "Stale")
        let eventState = provider.observe().sink { event in
            switch event {
            case ProviderEvent.ready:
                readyExpectation.fulfill()
            case ProviderEvent.error:
                errorExpectation.fulfill()
            case ProviderEvent.stale:
                staleExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }

        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [readyExpectation], timeout: 5)

        let client = OpenFeatureAPI.shared.getClient()

        let clientHook = BooleanHookMock()
        let invocationHook = BooleanHookMock()

        client.addHooks(clientHook)
        _ = client.getValue(
            key: "key",
            defaultValue: false,
            options: FlagEvaluationOptions(hooks: [invocationHook]))

        XCTAssertEqual(clientHook.beforeCalled, 1)
        XCTAssertEqual(invocationHook.beforeCalled, 1)
        XCTAssertNotNil(eventState)
    }

    func testBrokenProvider() {
        let provider = AlwaysBrokenProvider()
        let readyExpectation = XCTestExpectation(description: "Ready")
        let errorExpectation = XCTestExpectation(description: "Error")
        let staleExpectation = XCTestExpectation(description: "Stale")
        let eventState = provider.observe().sink { event in
            switch event {
            case ProviderEvent.ready:
                readyExpectation.fulfill()
            case ProviderEvent.error:
                errorExpectation.fulfill()
            case ProviderEvent.stale:
                staleExpectation.fulfill()
            default:
                XCTFail("Unexpected event")
            }
        }
        OpenFeatureAPI.shared.setProvider(provider: provider)
        wait(for: [errorExpectation], timeout: 5)

        let client = OpenFeatureAPI.shared.getClient()

        XCTAssertFalse(client.getValue(key: "testkey", defaultValue: false))
        let details = client.getDetails(key: "testkey", defaultValue: false)

        XCTAssertEqual(details.errorCode, .flagNotFound)
        XCTAssertEqual(details.reason, Reason.error.rawValue)
        XCTAssertEqual(details.errorMessage, "Could not find flag for key: testkey")
        XCTAssertNotNil(eventState)
    }

    func testClientMetadata() {
        let client1 = OpenFeatureAPI.shared.getClient()
        XCTAssertNil(client1.metadata.name)

        let client = OpenFeatureAPI.shared.getClient(name: "test", version: nil)
        XCTAssertEqual(client.metadata.name, "test")
    }
}
