import AppKit
import SwiftUI

struct TabCompletingTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let completion: String?
    let onAcceptCompletion: () -> Void
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.textColor = .white
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.controlSize = .small
        textField.lineBreakMode = .byTruncatingTail
        textField.cell?.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.cell?.wraps = false
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.parent = self
        textField.placeholderString = placeholder

        guard textField.stringValue != text else { return }
        textField.stringValue = text
        if let editor = textField.currentEditor() as? NSTextView {
            editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TabCompletingTextField

        init(parent: TabCompletingTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                let selection = textView.selectedRange()
                guard !textView.hasMarkedText(),
                      selection.length == 0,
                      selection.location == textView.string.utf16.count,
                      let completion = parent.completion,
                      !completion.isEmpty,
                      completion != parent.text
                else {
                    return false
                }

                parent.onAcceptCompletion()
                textView.string = completion
                textView.setSelectedRange(
                    NSRange(location: completion.utf16.count, length: 0)
                )
                (control as? NSTextField)?.stringValue = completion
                parent.text = completion
                return true
            }

            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }

            return false
        }
    }
}
