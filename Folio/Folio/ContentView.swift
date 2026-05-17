import SwiftUI
import SwiftData

/// Top-level container. Owns the focus state for the editor (so the
/// rollover orchestrator has direct access to it) and runs the midnight
/// rollover routine — quietly closing yesterday's page and creating
/// today's, deferred while the user is mid-edit per design.md §3.1.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Page.date, order: .reverse) private var allPages: [Page]
    @FocusState private var focusedElementID: UUID?

    var body: some View {
        Group {
            if let page = activePage {
                PageView(
                    page: page,
                    isPageClosed: isActivePageBeforeToday,
                    focusedElementID: $focusedElementID
                )
                // .id(page.id) tells SwiftUI to treat each page as a
                // distinct view, so swapping pages triggers the
                // .transition modifier below (rather than just an
                // in-place re-render). Combined with .animation on the
                // Group, this gives us the midnight cross-fade.
                .id(page.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Color.folioPaper.ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.6), value: activePage?.id)
        .task {
            ensurePageExists()
            attemptRollover()
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
        #endif
    }

    /// The page the user is currently interacting with — the latest one
    /// that hasn't been closed yet. Its date may be today, or yesterday
    /// during the brief window between midnight and quiet-completion.
    private var activePage: Page? {
        allPages.first { $0.closedAt == nil }
    }

    /// True when the active page belongs to a calendar day before today.
    /// Used to gate creation, drag, and tap-to-refocus while still
    /// allowing the currently-focused TextField to finish input.
    private var isActivePageBeforeToday: Bool {
        guard let page = activePage else { return false }
        return page.date < Calendar.current.startOfDay(for: .now)
    }

    /// First-run-of-the-day bootstrap. If no open page exists at all,
    /// create today's. Distinct from rollover, which also closes stale
    /// pages — this is for the very first launch when allPages is empty.
    private func ensurePageExists() {
        guard activePage == nil else { return }
        let new = Page(date: Calendar.current.startOfDay(for: .now))
        modelContext.insert(new)
    }

    /// Quietly closes any open page whose date is before today, and
    /// creates today's page if missing. Deferred (no-op) while any
    /// element is focused — see design.md §3.1 quiet completion.
    private func attemptRollover() {
        guard focusedElementID == nil else { return }

        let today = Calendar.current.startOfDay(for: .now)
        var didClose = false

        for page in allPages where page.closedAt == nil && page.date < today {
            // closedAt is the moment the page should have closed, not the
            // moment we detected it. Stays accurate even if the app was
            // away for several days.
            let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: page.date) ?? today
            page.closedAt = dayAfter
            didClose = true
        }

        let hasToday = allPages.contains { Calendar.current.isDate($0.date, equalTo: today, toGranularity: .day) }
        if !hasToday {
            let new = Page(date: today)
            modelContext.insert(new)
        }

        if didClose {
            FolioHaptic.pageClose()
        }
    }

    /// Runs whenever focus leaves an element. Trims whitespace; if the
    /// element is empty, removes it (so blank-commits don't leave ghosts
    /// on the page). Soft haptic confirms the commit either way.
    private func commitFocusedElement(oldID: UUID?) {
        guard let id = oldID,
              let page = activePage,
              let element = page.textElements.first(where: { $0.id == id }) else { return }

        let trimmed = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            modelContext.delete(element)
        }
        FolioHaptic.soft()
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
        .modelContainer(for: [Page.self, TextElement.self], inMemory: true)
}
