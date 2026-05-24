import SwiftUI
import SwiftData

/// Top-level container. Hosts a NavigationStack whose root is the journal
/// grid; the active editor and read-only page views are pushed destinations
/// keyed by Page.id. On launch we push today's id so the user lands on
/// today's editor; popping (book icon or left-edge swipe) reveals the grid.
///
/// All page-to-page transitions go through the iOS 18 navigation zoom
/// (.matchedTransitionSource on the source tile, .navigationTransition(.zoom)
/// on the destination), anchored on each tile's grid position.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Page.date, order: .reverse) private var allPages: [Page]
    @FocusState private var focusedElementID: UUID?
    @State private var path: [UUID] = []
    @Namespace private var pageNamespace

    var body: some View {
        NavigationStack(path: $path) {
            JournalView(pageNamespace: pageNamespace)
                .navigationDestination(for: UUID.self) { pageID in
                    pageDestination(for: pageID)
                }
        }
        .task {
            cleanupDuplicateTodayPages()
            attemptRollover()
            pushActivePageOnLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            attemptRollover()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                attemptRollover()
            }
        }
        .onChange(of: focusedElementID) { oldValue, _ in
            commitFocusedElement(oldID: oldValue)
            attemptRollover()
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            // Only show on the editor, not on the journal grid — the
            // grid's toolbar already occupies the top-trailing area.
            if !path.isEmpty {
                Button {
                    simulateMidnight()
                } label: {
                    Text("→ tomorrow")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.folioInk, in: Capsule())
                }
                .padding(8)
            }
        }
        #endif
    }

    /// Resolves a navigation destination for a page id. Today's page
    /// (closedAt == nil) renders the editable PageView and hides the
    /// system navigation bar — the in-page book icon and the left-edge
    /// swipe are the back affordances. Past pages render the read-only
    /// JournalPageView, which provides its own custom nav chrome.
    @ViewBuilder
    private func pageDestination(for pageID: UUID) -> some View {
        if let page = allPages.first(where: { $0.id == pageID }) {
            if page.closedAt == nil {
                PageView(
                    page: page,
                    isPageClosed: false,
                    focusedElementID: $focusedElementID,
                    onShowJournal: { popToJournal() }
                )
                .navigationTransition(.zoom(sourceID: pageID, in: pageNamespace))
                .toolbar(.hidden, for: .navigationBar)
            } else {
                JournalPageView(page: page)
                    .navigationTransition(.zoom(sourceID: pageID, in: pageNamespace))
            }
        }
    }

    /// The page the user is currently interacting with — the latest one
    /// that hasn't been closed yet.
    private var activePage: Page? {
        allPages.first { $0.closedAt == nil }
    }

    /// Heals an old race that could leave more than one unclosed page
    /// dated today in the store. Keeps the one with the most elements
    /// (almost always the one the user actually edited) and deletes the
    /// rest. SwiftData cascades the delete through .textElements.
    ///
    /// The race itself is now prevented in attemptRollover() via
    /// modelContext.fetchCount (which sees just-inserted pages within
    /// the same .task, unlike the reactive @Query allPages), so this
    /// cleanup is here for stores that built up duplicates under the
    /// old code path.
    private func cleanupDuplicateTodayPages() {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate<Page> { $0.closedAt == nil && $0.date == today }
        )
        let todays = (try? modelContext.fetch(descriptor)) ?? []
        guard todays.count > 1 else { return }

        let sorted = todays.sorted { $0.textElements.count > $1.textElements.count }
        for duplicate in sorted.dropFirst() {
            modelContext.delete(duplicate)
        }
    }

    /// On first appearance, push today's editor onto the navigation path
    /// so the user lands on it. We fetch directly via the modelContext
    /// (rather than reading allPages) because @Query may not have picked
    /// up a just-inserted page yet within this same .task.
    private func pushActivePageOnLaunch() {
        guard path.isEmpty else { return }
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate<Page> { $0.closedAt == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let active = try? modelContext.fetch(descriptor).first {
            path.append(active.id)
        }
    }

    /// Quietly closes any open page whose date is before today, and
    /// creates today's page if missing. Deferred (no-op) while any
    /// element is focused — see design.md §3.1 quiet completion.
    private func attemptRollover() {
        guard focusedElementID == nil else { return }

        let today = Calendar.current.startOfDay(for: .now)
        var justClosedIDs: [UUID] = []

        for page in allPages where page.closedAt == nil && page.date < today {
            // closedAt is the moment the page should have closed, not the
            // moment we detected it. Stays accurate even if the app was
            // away for several days.
            let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: page.date) ?? today
            page.closedAt = dayAfter
            justClosedIDs.append(page.id)
        }

        // Use fetchCount, not allPages.contains(...), because @Query may
        // not yet reflect a page that was inserted earlier in the same
        // .task (the bug that previously produced duplicate today pages).
        let todayDescriptor = FetchDescriptor<Page>(
            predicate: #Predicate<Page> { $0.date == today }
        )
        let existingTodayCount = (try? modelContext.fetchCount(todayDescriptor)) ?? 0
        if existingTodayCount == 0 {
            let new = Page(date: today)
            modelContext.insert(new)
        }

        if !justClosedIDs.isEmpty {
            FolioHaptic.pageClose()
            advancePathIfClosed(justClosedIDs: justClosedIDs)
        }
    }

    /// If the user was on a page that just closed (typical: yesterday's
    /// editor at midnight), replace the path's top with today's new page
    /// so they're carried forward rather than left looking at a now-closed
    /// page in the editor.
    private func advancePathIfClosed(justClosedIDs: [UUID]) {
        guard let top = path.last, justClosedIDs.contains(top) else { return }
        let descriptor = FetchDescriptor<Page>(
            predicate: #Predicate<Page> { $0.closedAt == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let newActive = try? modelContext.fetch(descriptor).first {
            path = [newActive.id]
        }
    }

    /// Pop the editor and reveal the journal grid. Called by PageView's
    /// book icon — equivalent to the user swiping from the left edge.
    private func popToJournal() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    /// Runs whenever focus leaves an element. For text elements: trims
    /// whitespace and removes the element if empty (no ghost elements).
    /// For location elements: just the haptic — empty name is a valid
    /// state (and the user might be in the middle of typing a new name).
    /// Soft haptic in both cases.
    private func commitFocusedElement(oldID: UUID?) {
        guard let id = oldID, let page = activePage else { return }

        if let text = page.textElements.first(where: { $0.id == id }) {
            let trimmed = text.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                modelContext.delete(text)
            }
            FolioHaptic.soft()
            return
        }

        if page.locationElements.contains(where: { $0.id == id }) {
            FolioHaptic.soft()
            return
        }
    }

    #if DEBUG
    /// Pretends a midnight has just passed. Moves the active page's date
    /// back one day and runs the rollover. Visible only in debug builds.
    private func simulateMidnight() {
        if let p = activePage {
            p.date = Calendar.current.date(byAdding: .day, value: -1, to: p.date) ?? p.date
        }
        attemptRollover()
    }
    #endif
}

#Preview {
    ContentView()
        .modelContainer(for: [Page.self, TextElement.self, VoiceMemoElement.self, LocationElement.self], inMemory: true)
}
