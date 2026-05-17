import SwiftUI
import SwiftData

/// Inline editor for a single TextElement. Borderless, sits directly on
/// the paper "like ink" per design.md §5.1. The parent (PageView) owns
/// focus state and tells us which element is currently being edited.
struct TextElementView: View {
    @Bindable var element: TextElement
    @FocusState.Binding var focusedElementID: UUID?

    var body: some View {
        TextField("", text: $element.text, axis: .vertical)
            .font(.system(size: element.fontSize, design: .serif))
            .foregroundStyle(Color.folioInk)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.leading)
            .focused($focusedElementID, equals: element.id)
            .frame(maxWidth: 240, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
