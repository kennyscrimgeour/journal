import SwiftUI
import SwiftData

/// Renders a single TextElement. The TextField is always present in the
/// view tree so its `.focused` binding can be wired up unconditionally;
/// this avoids a focus race that bit us when the TextField was hidden
/// behind `if isFocused { ... }`. Touch routing is controlled instead:
///
///   - focused:   TextField catches taps (cursor, selection), no drag.
///   - unfocused: TextField ignores hits; a transparent overlay catches
///                tap-to-refocus and drag-to-move.
struct TextElementView: View {
    @Bindable var element: TextElement
    @FocusState.Binding var focusedElementID: UUID?

    /// Visual offset accumulated during an in-progress drag. Committed back
    /// into element.positionX / positionY on drag end and reset to .zero.
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    private var isFocused: Bool { focusedElementID == element.id }

    var body: some View {
        TextField("", text: $element.text, axis: .vertical)
            .font(.system(size: element.fontSize, design: .serif))
            .foregroundStyle(Color.folioInk)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.leading)
            .focused($focusedElementID, equals: element.id)
            .frame(maxWidth: 240, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(isFocused)
            .overlay {
                if !isFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            focusedElementID = element.id
                        }
                        .gesture(dragGesture)
                }
            }
            .scaleEffect(isDragging ? 1.04 : 1.0)
            .shadow(
                color: .black.opacity(isDragging ? 0.18 : 0),
                radius: isDragging ? 8 : 0,
                x: 0,
                y: isDragging ? 4 : 0
            )
            .offset(dragOffset)
    }

    private var dragGesture: some Gesture {
        // coordinateSpace: .global is load-bearing. The gesture's target
        // (the overlay) sits inside the .offset(dragOffset) modifier, so
        // its .local coordinate space moves with the element. Translations
        // reported in that moving space create a feedback loop with the
        // offset. .global pins translations to screen coordinates.
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    // Wrap ONLY the isDragging flip so the spring applies
                    // to scale + shadow but not to the offset.
                    withAnimation(.spring(duration: 0.3, bounce: 0)) {
                        isDragging = true
                    }
                    FolioHaptic.soft()
                }
                // No withAnimation here — offset must track the finger 1:1.
                dragOffset = value.translation
            }
            .onEnded { value in
                // Persist the new position and zero the transient in the
                // same (non-animated) transaction so the visual stays put.
                element.positionX += value.translation.width
                element.positionY += value.translation.height
                dragOffset = .zero
                withAnimation(.spring(duration: 0.3, bounce: 0)) {
                    isDragging = false
                }
                FolioHaptic.soft()
            }
    }
}
