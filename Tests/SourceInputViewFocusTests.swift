import AppKit
import Defaults
import SwiftUI
import XCTest
@testable import MoePeek

@MainActor
final class SourceInputViewFocusTests: XCTestCase {
    func testTextViewBecomesFirstResponderWhenAttachedToPanel() throws {
        let previousInputSource = Defaults[.defaultInputSource]
        Defaults[.defaultInputSource] = ""
        defer { Defaults[.defaultInputSource] = previousInputSource }

        let panel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))
        let hostingView = NSHostingView(
            rootView: SourceInputView(text: .constant(""), onSubmit: {})
        )
        defer {
            panel.contentView = nil
            panel.close()
        }
        panel.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        let textView = try XCTUnwrap(findTextView(in: hostingView))
        XCTAssertTrue(panel.initialFirstResponder === textView)
        XCTAssertTrue(panel.firstResponder === textView)
    }

    func testConfiguredInputSourceIsAppliedOnFocus() throws {
        let probe = NSTextView()
        let inputContext = try XCTUnwrap(probe.inputContext)
        let previousInputSource = inputContext.selectedKeyboardInputSource
        let configuredInputSource = try XCTUnwrap(
            inputContext.keyboardInputSources?.first { $0 != previousInputSource }
                ?? previousInputSource
        )
        let previousDefault = Defaults[.defaultInputSource]
        Defaults[.defaultInputSource] = configuredInputSource
        defer {
            Defaults[.defaultInputSource] = previousDefault
            inputContext.selectedKeyboardInputSource = previousInputSource
        }

        let panel = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200))
        let hostingView = NSHostingView(
            rootView: SourceInputView(text: .constant(""), onSubmit: {})
        )
        defer {
            panel.contentView = nil
            panel.close()
        }
        panel.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        let textView = try XCTUnwrap(findTextView(in: hostingView))
        XCTAssertEqual(textView.inputContext?.selectedKeyboardInputSource, configuredInputSource)
    }

    private func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }
        return view.subviews.lazy.compactMap(findTextView).first
    }
}
