import Defaults
import XCTest
@testable import MoePeek

final class CodexProviderTests: XCTestCase {
    func testDefaultModelAppearsInCodexCatalog() {
        let provider = CodexProvider()

        XCTAssertTrue(CodexProvider.availableModels.contains(provider.modelKey.defaultValue))
    }

    func testSelectedCodexModelsRunWithDefaultModel() {
        let provider = CodexProvider()
        let previousModel = Defaults[provider.modelKey]
        let previousEnabledModels = Defaults[provider.enabledModelsKey]
        defer {
            Defaults[provider.modelKey] = previousModel
            Defaults[provider.enabledModelsKey] = previousEnabledModels
        }

        Defaults[provider.modelKey] = "gpt-5.4-mini"
        Defaults[provider.enabledModelsKey] = ["gpt-5.4", "gpt-5.3-codex-spark"]

        XCTAssertEqual(
            provider.activeModels,
            ["gpt-5.3-codex-spark", "gpt-5.4", "gpt-5.4-mini"]
        )
    }

    func testDeviceCodeAcceptsNumericAndStringIntervals() throws {
        let numeric = try decodeDeviceCode(interval: "2")
        let string = try decodeDeviceCode(interval: "\"3.5\"")

        XCTAssertEqual(numeric.interval, 2)
        XCTAssertEqual(string.interval, 3.5)
    }

    func testDeviceCodeRejectsInvalidIntervals() {
        for interval in ["-1", "\"nan\"", "\"infinity\""] {
            XCTAssertThrowsError(try decodeDeviceCode(interval: interval))
        }
    }

    func testStreamRequiresTerminalEvent() throws {
        var parser = CodexStreamParser()
        let delta = try parser.consume(
            line: "data: {\"type\":\"response.output_text.delta\",\"delta\":\"hello\"}"
        )

        XCTAssertEqual(delta, "hello")
        XCTAssertThrowsError(try parser.finish())

        _ = try parser.consume(line: "data: {\"type\":\"response.completed\"}")
        XCTAssertNoThrow(try parser.finish())
    }

    func testStreamRejectsMalformedAndErrorEvents() {
        var malformedParser = CodexStreamParser()
        XCTAssertThrowsError(try malformedParser.consume(line: "data: not-json"))

        var errorParser = CodexStreamParser()
        XCTAssertThrowsError(
            try errorParser.consume(
                line: "data: {\"type\":\"error\",\"error\":{\"message\":\"denied\"}}"
            )
        )

        var incompleteParser = CodexStreamParser()
        XCTAssertThrowsError(
            try incompleteParser.consume(line: "data: {\"type\":\"response.incomplete\"}")
        )
    }

    private func decodeDeviceCode(interval: String) throws -> DeviceCode {
        let json = """
        {"device_auth_id":"device","user_code":"CODE","interval":\(interval)}
        """
        return try JSONDecoder().decode(DeviceCode.self, from: Data(json.utf8))
    }
}
