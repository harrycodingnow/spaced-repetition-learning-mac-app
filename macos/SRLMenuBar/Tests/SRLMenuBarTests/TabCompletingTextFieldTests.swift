import AppKit
import SwiftUI
import Testing
@testable import SRLMenuBar

struct TabCompletingTextFieldTests {
    @MainActor
    @Test("Tab accepts a visible completion and keeps the editor current")
    func acceptsCompletion() {
        let state = TextState("two")
        var accepted = false
        let field = TabCompletingTextField(
            text: Binding(
                get: { state.value },
                set: { state.value = $0 }
            ),
            placeholder: "Question",
            completion: "Two Sum",
            onAcceptCompletion: { accepted = true },
            onSubmit: {}
        )
        let coordinator = field.makeCoordinator()
        let control = NSTextField()
        let editor = NSTextView()
        editor.string = "two"
        editor.setSelectedRange(NSRange(location: 3, length: 0))

        let handled = coordinator.control(
            control,
            textView: editor,
            doCommandBy: #selector(NSResponder.insertTab(_:))
        )

        #expect(handled)
        #expect(accepted)
        #expect(state.value == "Two Sum")
        #expect(editor.string == "Two Sum")
        #expect(editor.selectedRange() == NSRange(location: 7, length: 0))
    }

    @MainActor
    @Test("Tab preserves normal focus traversal without a completion")
    func preservesTabTraversal() {
        let state = TextState("unknown")
        let field = TabCompletingTextField(
            text: Binding(
                get: { state.value },
                set: { state.value = $0 }
            ),
            placeholder: "Question",
            completion: nil,
            onAcceptCompletion: {},
            onSubmit: {}
        )
        let editor = NSTextView()
        editor.string = state.value
        editor.setSelectedRange(NSRange(location: state.value.utf16.count, length: 0))

        let handled = field.makeCoordinator().control(
            NSTextField(),
            textView: editor,
            doCommandBy: #selector(NSResponder.insertTab(_:))
        )

        #expect(!handled)
        #expect(state.value == "unknown")
    }
}

private final class TextState {
    var value: String

    init(_ value: String) {
        self.value = value
    }
}
