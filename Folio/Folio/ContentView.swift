import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Page.date, order: .reverse) private var allPages: [Page]

    var body: some View {
        ZStack(alignment: .top) {
            Self.paper.ignoresSafeArea()

            if let page = todayPage {
                Text(page.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Self.ink)
                    .padding(.top, 8)
            }
        }
        .task { ensureTodayPageExists() }
    }

    /// Today's page, if it exists in the store yet. We compute this from
    /// the @Query results rather than holding a separate @State reference,
    /// so the view stays consistent with the database in one direction.
    private var todayPage: Page? {
        let calendar = Calendar.current
        return allPages.first { calendar.isDateInToday($0.date) }
    }

    /// First-run-of-the-day bootstrap. If today's page isn't in the store,
    /// create it. SwiftData notices the insert, @Query re-emits, and the
    /// view re-renders with the date visible.
    private func ensureTodayPageExists() {
        guard todayPage == nil else { return }
        let new = Page(date: Calendar.current.startOfDay(for: .now))
        modelContext.insert(new)
    }

    /// Cream off-white, slightly warm. Per design.md §8.1.
    /// Temporary as a flat colour — the paper texture comes later.
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)

    /// Deep warm near-black. Never pure #000. Per design.md §8.1.
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.14)
}

#Preview {
    ContentView()
        .modelContainer(for: [Page.self, TextElement.self], inMemory: true)
}
