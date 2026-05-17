import SwiftUI
import SwiftData

/// Renders a single TextElement. The TextField is always present in the
/// view tree so its `.focused` binding can be wired up unconditionally;
/// this avoids a focus race that bit us when the TextField was hidden
/// behind `if isFocused { ... }`. Touch routing is controlled instead:
///
///   - focused:   TextField catches taps (cursor, selection), no drag.
///   - unfocused: TextField ignores hits; a transparent overlay catches
///                tap-to-refocus and drag-to-move — both suppressed
///                when the page is read-only (post-midnight).
struct TextElementView: View {
    @Bindable var element: TextElement
    @FocusState.Binding var focusedElementID: UUID?
    /// True after midnight on a page that hasn't yet quiet-completed.
    /// Suppresses drag and tap-to-refocus, but leaves the currently
    /// focused TextField interactive — see design.md §3.1.
    let isPageClosed: Bool
    /// Bounds of the page canvas. Used to clamp commit positions so
    /// off-edge drops don't fly off-screen, and to detect drops into
    /// the bottom delete strip.
    let canvasSize: CGSize
    /// Height in points of the bottom strip that counts as the delete
    /// zone. PageView positions the trash icon within this strip and
    /// fades it in as the user approaches.
    let bottomDeleteZone: CGFloat
    /// Called with the live projected element-centre during a drag,
    /// and with nil when the drag ends. PageView uses this both to
    /// decide whether to surface the trash icon and to know "some
    /// element is currently being dragged."
    let onDragChange: (CGPoint?) -> Void
    /// Called when the drag releases inside the bottom delete strip.
    /// PageView owns modelContext.delete so this view doesn't need it.
    let onDelete: () -> Void

    /// Visual offset accumulated during an in-progress drag. Committed back
    /// into element.positionX / positionY on drag end and reset to .zero.
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    private var isFocused: Bool { focusedElementID == element.id }

    /// Rough element-centre offsets from the stored top-leading position.
    /// We don't measure the real height (would need GeometryReader inside
    /// the element), so we use sensible defaults; refine if elements get
    /// much bigger than a couple of lines.
    private static let estimatedHalfWidth: CGFloat = 120  // half of maxWidth 240
    private static let estimatedHalfHeight: CGFloat = 15

    /// True when the projected centre of the element (during an in-progress
    /// drag) sits inside the bottom delete strip. Drives both the opacity
    /// fade (live feedback) and the release-to-delete decision.
    private var isInDeleteZone: Bool {
        guard isDragging else { return false }
        return isInBottomDeleteZone(translation: dragOffset)
    }

    private func projectedCentre(translation: CGSize) -> CGPoint {
        CGPoint(
            x: element.positionX + translation.width + Self.estimatedHalfWidth,
            y: element.positionY + translation.height + Self.estimatedHalfHeight
        )
    }

    private func isInBottomDeleteZone(translation: CGSize) -> Bool {
        let c = projectedCentre(translation: translation)
        return c.y > canvasSize.height - bottomDeleteZone
    }

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
                    unfocusedOverlay
                }
            }
            .scaleEffect(isDragging ? 1.04 : 1.0)
            .shadow(
                color: .black.opacity(isDragging ? 0.18 : 0),
                radius: isDragging ? 8 : 0,
                x: 0,
                y: isDragging ? 4 : 0
            )
            .opacity(isInDeleteZone ? 0.4 : 1.0)
            .offset(dragOffset)
    }

    /// The transparent gesture-catcher that sits on top of the TextField
    /// when it's not focused. On a closed page the overlay still exists
    /// (so taps don't accidentally fall through to canvas-tap creation)
    /// but carries no gestures — existing text is read-only.
    @ViewBuilder
    private var unfocusedOverlay: some View {
        let base = Color.clear.contentShape(Rectangle())

        if isPageClosed {
            base
        } else {
            base
                .onTapGesture {
                    focusedElementID = element.id
                }
                .gesture(dragGesture)
        }
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
                onDragChange(projectedCentre(translation: value.translation))
            }
            .onEnded { value in
                if isInBottomDeleteZone(translation: value.translation) {
                    FolioHaptic.delete()
                    onDelete()
                    onDragChange(nil)
                    return
                }

                // Commit position, clamping the centre to canvas bounds so
                // off-left/right/top drops don't fly fully off-screen.
                let raw = projectedCentre(translation: value.translation)
                let cx = max(0, min(canvasSize.width, raw.x))
                let cy = max(0, min(canvasSize.height, raw.y))
                element.positionX = cx - Self.estimatedHalfWidth
                element.positionY = cy - Self.estimatedHalfHeight
                dragOffset = .zero
                withAnimation(.spring(duration: 0.3, bounce: 0)) {
                    isDragging = false
                }
                FolioHaptic.soft()
                onDragChange(nil)
            }
    }
}
