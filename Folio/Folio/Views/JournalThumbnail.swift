import SwiftUI
import SwiftData

/// Renders a past page as a small card in the journal grid. The card's
/// content is generated via ImageRenderer (iOS 16+) by rasterising a
/// non-interactive miniature of the page — the same cream paper, date
/// header, and text elements at their stored positions, but no gestures.
///
/// The rendered image is cached in @State per-view. When the cell scrolls
/// offscreen and back, ImageRenderer re-runs; for current journal sizes
/// this is fine, and we can add an external cache later if needed.
struct JournalThumbnail: View {
    let page: Page

    @State private var rendered: UIImage?

    /// Canonical "page size" we render thumbnails against. Using a fixed
    /// size (rather than the live device size) keeps every thumbnail at
    /// the same aspect ratio in the grid. Roughly iPhone 15 logical points.
    private static let pageRenderSize = CGSize(width: 393, height: 852)

    var body: some View {
        Group {
            if let rendered {
                Image(uiImage: rendered)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.folioPaper
            }
        }
        .aspectRatio(Self.pageRenderSize.width / Self.pageRenderSize.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 1)
        .task {
            await renderThumbnail()
        }
    }

    @MainActor
    private func renderThumbnail() async {
        let content = PageThumbnailContent(page: page)
            .frame(width: Self.pageRenderSize.width, height: Self.pageRenderSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2.0
        rendered = renderer.uiImage
    }
}

/// Non-interactive miniature of a page, the input to ImageRenderer.
/// Mirrors PageView's body — same paper, date typography, element
/// positions — minus gestures, focus state, and the journal icon.
private struct PageThumbnailContent: View {
    let page: Page

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.folioPaper

            Text(page.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.folioInk)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            ForEach(page.textElements) { element in
                Text(element.text)
                    .font(.system(size: element.fontSize, design: .serif))
                    .foregroundStyle(Color.folioInk)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 240, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .rotationEffect(.radians(element.rotationRadians))
                    .offset(x: element.positionX, y: element.positionY)
            }

            ForEach(page.voiceMemoElements) { memo in
                VoiceMemoThumbnail(samples: memo.waveformSamples)
                    .rotationEffect(.radians(memo.rotationRadians))
                    .offset(x: memo.positionX, y: memo.positionY)
            }

            ForEach(page.locationElements) { loc in
                LocationThumbnail(name: loc.displayName)
                    .rotationEffect(.radians(loc.rotationRadians))
                    .offset(x: loc.positionX, y: loc.positionY)
            }
        }
    }
}

/// Miniature location sticker for journal thumbnails. Mirrors the
/// editor's polaroid but without rounding hover/edit state.
private struct LocationThumbnail: View {
    let name: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin")
                .font(.system(size: 13))
                .foregroundStyle(Color.folioInk.opacity(0.65))
            Text(name)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(Color.folioInk)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 200, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.folioPaper)
        .overlay(Rectangle().stroke(Color.white, lineWidth: 6))
        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
    }
}

/// Static miniature pill for use inside ImageRenderer-rendered
/// thumbnails. Mirrors the editor's pill but skips the caption — the
/// duration would be unreadable at thumbnail scale.
private struct VoiceMemoThumbnail: View {
    let samples: [Double]

    var body: some View {
        waveform
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 180, height: 40)
            .background(Capsule().fill(Color.folioPaper))
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
    }

    private var waveform: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let spacing: CGFloat = 1
            let count = samples.count
            let barWidth = max(1, (size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            let colour = Color.folioInk.opacity(0.75)
            for (i, sample) in samples.enumerated() {
                let height = max(2, size.height * CGFloat(sample))
                let x = CGFloat(i) * (barWidth + spacing)
                let y = (size.height - height) / 2
                context.fill(
                    Path(CGRect(x: x, y: y, width: barWidth, height: height)),
                    with: .color(colour)
                )
            }
        }
    }
}
