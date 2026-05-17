import SwiftUI
import SwiftData

/// Top-level container. Responsible for finding (or creating) today's Page
/// and handing it to PageView. Owns no visual chrome of its own — once we
/// have a page, the entire screen is the page.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Page.date, order: .reverse) private var allPages: [Page]

    var body: some View {
        Group {
            if let page = todayPage {
                PageView(page: page)
            } else {
                Color.folioPaper.ignoresSafeArea()
            }
        }
        .task { ensureTodayPageExists() }
    }

    private var todayPage: Page? {
        let calendar = Calendar.current
        return allPages.first { calendar.isDateInToday($0.date) }
    }

    private func ensureTodayPageExists() {
        guard todayPage == nil else { return }
        let new = Page(date: Calendar.current.startOfDay(for: .now))
        modelContext.insert(new)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Page.self, TextElement.self], inMemory: true)
}
