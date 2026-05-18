import SwiftUI
import SwiftData

/// Slice 8 placeholder for a voice memo sticker. Renders a small
/// rectangle with a waveform glyph and the recording's duration, with
/// drag + drag-to-delete reusing the pattern from TextElementView.
/// Slice 9 replaces this body with a proper polaroid sticker that
/// renders the actual audio waveform.
struct VoiceMemoElementView: View {
    @Bindable var element: VoiceMemoElement
    let isPageClosed: Bool
    let canvasSize: CGSize
    let bottomDeleteZone: CGFloat
    let onDragChange: (CGPoint?) -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    /// Rough half-extents for the placeholder sticker. Used for the
    /// projected-centre math (delete-zone check, clamping). Slice 9
    /// will measure the real sticker dimensions properly.
    private static let estimatedHalfWidth: CGFloat = 90
    private static let estimatedHalfHeight: CGFloat = 28

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
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 18))
                .foregroundStyle(Color.folioInk)
            Text(formattedDuration)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(Color.folioInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.folioPaper)
        .overlay(Rectangle().stroke(Color.white, lineWidth: 6))
        .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)
        .rotationEffect(.radians(element.rotationRadians))
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .opacity(isInDeleteZone ? 0.4 : 1.0)
        .offset(dragOffset)
        .gesture(dragGesture, isEnabled: !isPageClosed)
    }

    private var formattedDuration: String {
        let secs = Int(element.durationSeconds)
        return String(format: "%d:%02d", secs / 60, secs % 60)
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
