import SwiftUI
import SwiftData

/// The journal — your pages, displayed as a quiet grid with today's
/// tile at the top. Per design.md §7 (revised 2026-05-17): the journal
/// is the hub view; the active editor is one navigation push away.
/// No search, no tags, no algorithmic resurfacing — just browsing.
struct JournalView: View {
    let pageNamespace: Namespace.ID

    @Query(sort: \Page.date, order: .reverse) private var allPages: [Page]

    private static let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                ForEach(allPages) { page in
                    NavigationLink(value: page.id) {
                        JournalThumbnail(page: page)
                    }
                    .matchedTransitionSource(id: page.id, in: pageNamespace) { config in
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
        }
    }
}
