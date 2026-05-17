import SwiftUI
import SwiftData

/// The spatial canvas for one Page. Owns the cream paper, the date header,
/// the layout of all text elements at their (positionX, positionY), the
/// tap-to-create gesture, and the focus state that tracks which element
/// is currently being edited.
///
/// Keyboard avoidance is handled manually: SwiftUI's automatic avoidance
/// under-shifts when content is absolutely positioned with `.offset`, so
/// we observe keyboard notifications directly and lift the canvas just
/// enough to keep the focused element above the keyboard.
struct PageView: View {
    let page: Page

    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedElementID: UUID?
    @State private var keyboardHeight: CGFloat = 0

    /// Vertical space at the top of the page reserved for the date header.
    /// Taps above this line never create a new element (but still commit
    /// an in-progress edit). Adjust if the date typography changes.
    private static let topContentInset: CGFloat = 40

    /// Visible space we try to keep below a focused element before the
    /// keyboard edge — gives the cursor a little breathing room rather
    /// than parking the element flush against the keyboard.
    private static let focusedElementBreath: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.folioPaper

                Text(page.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.folioInk)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                ForEach(page.textElements) { element in
                    TextElementView(element: element, focusedElementID: $focusedElementID)
                        .offset(x: element.positionX, y: element.positionY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .offset(y: canvasLift(viewportHeight: geometry.size.height))
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        handleCanvasTap(at: event.location)
                    }
            )
        }
        .background(Color.folioPaper.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        .animation(.easeOut(duration: 0.25), value: focusedElementID)
        .onChange(of: focusedElementID) { oldValue, _ in
            commitElement(withID: oldValue)
        }
    }

    /// How many points to lift the canvas so the focused element stays
    /// visible above the keyboard. Zero when no keyboard or no focused
    /// element, or when the element is already comfortably visible.
    private func canvasLift(viewportHeight: CGFloat) -> CGFloat {
        guard keyboardHeight > 0,
              let id = focusedElementID,
              let element = page.textElements.first(where: { $0.id == id })
        else { return 0 }

        let visibleHeight = viewportHeight - keyboardHeight
        let targetVisibleBottom = element.positionY + Self.focusedElementBreath
        let overhang = targetVisibleBottom - visibleHeight
        return overhang > 0 ? -overhang : 0
    }

    /// Honours the chosen tap-while-editing rule (commit, do not create
    /// a new element on this tap). Only an empty-page tap with no element
    /// currently focused creates a new element.
    private func handleCanvasTap(at location: CGPoint) {
        // Any canvas tap commits an in-progress edit, regardless of where
        // on the page it lands.
        if focusedElementID != nil {
            focusedElementID = nil
            return
        }

        // Creation is gated by the top boundary — the date header sits
        // there and should not be writable over.
        guard location.y >= Self.topContentInset else { return }

        let new = TextElement(positionX: location.x, positionY: location.y)
        page.textElements.append(new)
        focusedElementID = new.id
        FolioHaptic.soft()
    }

    /// When focus leaves an element we either keep it (text is non-empty)
    /// or delete it (text is empty or whitespace-only). Either way, fire a
    /// soft haptic so the commit is felt.
    private func commitElement(withID id: UUID?) {
        guard let id else { return }
        guard let element = page.textElements.first(where: { $0.id == id }) else { return }

        let trimmed = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            modelContext.delete(element)
        }
        FolioHaptic.soft()
    }
}
