import SwiftUI
import SwiftData

/// Voice memo sticker — a rounded-pill capsule containing a rendered
/// waveform and the recording's duration, per the design.md §5.2
/// pill-form revision. Drag + drag-to-bottom-delete reuse the pattern
/// from TextElementView. Playback (tap to play / pause) lands in
/// slice 10.
struct VoiceMemoElementView: View {
    @Bindable var element: VoiceMemoElement
    let isPageClosed: Bool
    let canvasSize: CGSize
    let bottomDeleteZone: CGFloat
    let onDragChange: (CGPoint?) -> Void
    let onDelete: () -> Void
    /// Owned by the parent PageView so a single player serves every
    /// memo on the page (and only one plays at a time).
    let audioPlayer: AudioPlayer

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    /// Sticker dimensions used for both layout and the projected-centre
    /// maths (delete zone, drop-position clamping). Keep these in sync
    /// with the .frame on the pill body below.
    private static let stickerWidth: CGFloat = 180
    private static let stickerHeight: CGFloat = 40
    private static let estimatedHalfWidth: CGFloat = stickerWidth / 2
    private static let estimatedHalfHeight: CGFloat = stickerHeight / 2

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
        pillSticker
            .rotationEffect(.radians(element.rotationRadians))
            .scaleEffect(isDragging ? 1.04 : 1.0)
            .opacity(isInDeleteZone ? 0.4 : 1.0)
            .offset(dragOffset)
            .contentShape(Capsule())
            .onTapGesture {
                audioPlayer.toggle(element)
            }
            .gesture(dragGesture, isEnabled: !isPageClosed)
    }

    /// The rounded-pill sticker: cream capsule, soft drop shadow, no
    /// border. Waveform fills most of the width; duration sits at the
    /// trailing edge in small serif. Per design.md §5.2.
    private var pillSticker: some View {
        HStack(spacing: 8) {
            waveformCanvas
            Text(formattedDuration)
                .font(.system(.caption2, design: .serif))
                .foregroundStyle(Color.folioInk.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: Self.stickerWidth, height: Self.stickerHeight)
        .background(Capsule().fill(Color.folioPaper))
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
    }

    /// Canvas-drawn waveform: one bar per amplitude sample, heights
    /// proportional to amplitude, centred vertically. During playback
    /// the bars to the left of the current progress render at higher
    /// opacity than the unplayed ones — the waveform is the scrubber.
    /// For voice memos recorded before slice 9 (empty waveformSamples)
    /// renders a row of subtle dots so the sticker isn't blank.
    private var waveformCanvas: some View {
        let isPlaying = audioPlayer.isPlaying(element)
        let progress = isPlaying ? audioPlayer.progress : 0

        return Canvas { context, size in
            let samples = element.waveformSamples
            guard !samples.isEmpty else {
                drawDottedPlaceholder(context: context, size: size)
                return
            }

            let spacing: CGFloat = 1
            let count = samples.count
            let barWidth = max(1, (size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            let progressX = size.width * CGFloat(progress)

            let playedColour = Color.folioInk.opacity(0.9)
            let unplayedColour = Color.folioInk.opacity(0.4)
            let idleColour = Color.folioInk.opacity(0.75)

            for (i, sample) in samples.enumerated() {
                let height = max(2, size.height * CGFloat(sample))
                let x = CGFloat(i) * (barWidth + spacing)
                let y = (size.height - height) / 2
                let rect = CGRect(x: x, y: y, width: barWidth, height: height)

                let colour: Color
                if isPlaying {
                    let barCentre = x + barWidth / 2
                    colour = barCentre < progressX ? playedColour : unplayedColour
                } else {
                    colour = idleColour
                }

                context.fill(Path(rect), with: .color(colour))
            }
        }
    }

    private func drawDottedPlaceholder(context: GraphicsContext, size: CGSize) {
        let dotCount = 12
        let dotWidth: CGFloat = 2
        let spacing: CGFloat = 4
        let total = CGFloat(dotCount) * dotWidth + CGFloat(dotCount - 1) * spacing
        let startX = (size.width - total) / 2
        let colour = Color.folioInk.opacity(0.25)
        for i in 0..<dotCount {
            let x = startX + CGFloat(i) * (dotWidth + spacing)
            let rect = CGRect(x: x, y: size.height / 2 - 1, width: dotWidth, height: 2)
            context.fill(Path(rect), with: .color(colour))
        }
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
