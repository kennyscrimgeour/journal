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
        }
    }
}
