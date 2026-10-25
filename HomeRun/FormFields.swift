import SwiftUI

/// System text entry. SwiftUI fields that inherit the variable brand font were not accepting taps on this OS.
struct EntryField: UIViewRepresentable {
    var title: String
    @Binding var text: String
    var prompt: String = ""
    var axis: Axis = .horizontal
    var keyboard: UIKeyboardType = .default
    var identifier: String = ""
    var focused: Bool = false

    init(_ title: String, text: Binding<String>, prompt: String = "", axis: Axis = .horizontal, keyboard: UIKeyboardType = .default, identifier: String = "", focused: Bool = false) {
        self.title = title
        self._text = text
        self.prompt = prompt
        self.axis = axis
        self.keyboard = keyboard
        self.identifier = identifier
        self.focused = focused
    }

    init(_ title: String, text: Binding<String>, prompt: Text, axis: Axis = .horizontal) {
        self.init(title, text: text, axis: axis)
    }

    func makeUIView(context: Context) -> UIView {
        if axis == .vertical {
            let view = UITextView()
            view.font = Theme.fieldFont()
            view.backgroundColor = .clear
            view.textColor = UIColor(red: 28 / 255, green: 18 / 255, blue: 20 / 255, alpha: 1)
            view.isScrollEnabled = true
            view.delegate = context.coordinator
            view.text = text
            view.accessibilityLabel = title
            if !identifier.isEmpty { view.accessibilityIdentifier = identifier }
            return view
        }
        let field = UITextField()
        field.font = Theme.fieldFont()
        field.textColor = UIColor(red: 28 / 255, green: 18 / 255, blue: 20 / 255, alpha: 1)
        field.placeholder = prompt.isEmpty ? title : prompt
        field.keyboardType = keyboard
        field.autocorrectionType = .yes
        field.clearButtonMode = .whileEditing
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.text = text
        field.accessibilityLabel = title
        if !identifier.isEmpty { field.accessibilityIdentifier = identifier }
        return field
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        if let field = uiView as? UITextField {
            if field.text != text { field.text = text }
            field.keyboardType = keyboard
        } else if let view = uiView as? UITextView, view.text != text, !view.isFirstResponder {
            view.text = text
        }
        if focused, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: EntryField
        init(_ parent: EntryField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
    }
}

struct RequiredLabel: View {
    var title: String
    var required: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(title)
                .font(Theme.text(.footnote, weight: .semibold))
                .foregroundStyle(Theme.muted)
            if required {
                Text("*")
                    .font(Theme.text(.footnote, weight: .bold))
                    .foregroundStyle(Theme.bad)
                    .accessibilityLabel("required")
            } else {
                Text("Optional")
                    .font(Theme.text(.caption2))
                    .foregroundStyle(Theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
