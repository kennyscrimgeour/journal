import SwiftUI
import SwiftData

/// The journal — past, closed pages displayed as a quiet grid.
/// Per design.md §7: a place you visit on purpose. No search, no tags,
/// no algorithmic resurfacing — just browsing.
struct JournalView: View {
    let onClose: () -> Void

    @Query(sort: \Page.date, order: .reverse) private var allPages: [Page]
    @Namespace private var thumbnailNamespace

    /// Past pages only — today's open page belongs to the editor, not
    /// the journal. Filter in Swift rather than via #Predicate so we
    /// stay clear of SwiftData predicate quirks around nil checks.
    private var closedPages: [Page] {
        allPages.filter { $0.closedAt != nil }
    }

    private static let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                    ForEach(closedPages) { page in
                        NavigationLink {
                            JournalPageView(page: page)
                                .navigationTransition(.zoom(sourceID: page.id, in: thumbnailNamespace))
                        } label: {
                            JournalThumbnail(page: page)
                        }
                        .matchedTransitionSource(id: page.id, in: thumbnailNamespace) { config in
                            // Suppress the default placeholder background
                            // and match the thumbnail's rounded clip so the
                            // zoom-back doesn't leave a hard rectangle
                            // outline behind the returning card.
                            config
                                .background(.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .background(Color.folioJournalBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.folioJournalBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Journal")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.folioInk)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.folioInk)
                }
            }
        }
    }
}
