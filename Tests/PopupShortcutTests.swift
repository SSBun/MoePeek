import XCTest
@testable import MoePeek

final class PopupShortcutTests: XCTestCase {
    func testResultShortcutUsesVisibleSlotIndex() {
        let states: [String: TranslationCoordinator.ProviderState] = [
            "first": .error(message: "failed"),
            "second": .completed(text: "translated"),
        ]

        XCTAssertNil(
            PopupView.completedTranslation(
                atResultIndex: 0,
                slotIDs: ["first", "second"],
                providerStates: states
            )
        )
        XCTAssertEqual(
            PopupView.completedTranslation(
                atResultIndex: 1,
                slotIDs: ["first", "second"],
                providerStates: states
            ),
            "translated"
        )
    }
}
