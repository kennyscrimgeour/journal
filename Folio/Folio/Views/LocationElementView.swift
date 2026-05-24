import SwiftUI
import SwiftData

/// Location sticker — polaroid-style cream card with a small pin glyph
/// and the place name in serif, per design.md §5.4. Auto-sizes to the
/// length of the name, up to a comfortable max width. Drag + delete
/// reuse the pattern from the other element views.
///
/// Slice 11c renders display only; slice 11d adds tap-to-edit for the
/// design.md "the cafe on the corner" override.
struct LocationElementView: View {
    @Bindable var element: LocationElement
    let isPageClosed: Bool
    let canvasSize: CGSize
    let bottomDeleteZone: CGFloat
    let onDragChange: (CGPoint?) -> Void
    let onDelete: () -> Void
    /// Shared focus state lifted up to PageView. When equals element.id
    /// this sticker is in name-edit mode. Sharing the focus state with
    /// text elements means PageView's keyboard-avoidance lift extends
    /// to location edits for free.
    @FocusState.Binding var focusedElementID: UUID?

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    private var isEditingName: Bool { focusedElementID == element.id }

    /// Rough half-extents for the projected-centre maths (delete zone,
    /// drop-position clamping). Names vary in length so this is an
    /// approximation; landing in the delete zone gets a forgiving check
    /// anyway.
    private static let estimatedHalfWidth: CGFloat = 70
    private static let estimatedHalfHeight: CGFloat = 18

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
        polaroidSticker
            .rotationEffect(.radians(element.rotationRadians))
            .scaleEffect(isDragging ? 1.04 : 1.0)
            .opacity(isInDeleteZone ? 0.4 : 1.0)
            .offset(dragOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isPageClosed, !isEditingName else { return }
                focusedElementID = element.id
            }
            .gesture(dragGesture, isEnabled: !isPageClosed && !isEditingName)
    }

    private var polaroidSticker: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin")
                .font(.system(size: 13))
                .foregroundStyle(Color.folioInk.opacity(0.65))

            // TextField is always in the view tree (rather than swapped
            // with a Text via if/else) so its .focused binding never
            // races with view-tree changes — same lesson learned in
            // slice 3 for text elements. Hit testing toggles instead.
            TextField("", text: $element.displayName, axis: .vertical)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(Color.folioInk)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .focused($focusedElementID, equals: element.id)
                .frame(maxWidth: 160, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .allowsHitTesting(isEditingName)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 200, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.folioPaper)
        .overlay(Rectangle().stroke(Color.white, lineWidth: 6))
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if !isDragging {
                    withAnimation(.spring(duration: 0.3, bounce: 0)) {
                        isDragging = true
                    }
                    FolioHaptic.soft()
                }
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
