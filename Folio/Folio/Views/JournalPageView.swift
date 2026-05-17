import SwiftUI
import SwiftData

/// Read-only full-page display of a closed page from the journal.
/// Wraps PageView with isPageClosed=true so every interaction path
/// (tap-create, drag, tap-to-refocus) is suppressed. Date moves out of
/// the page canvas and into the nav toolbar so the back button and the
/// date share a single line of serif chrome.
struct JournalPageView: View {
    let page: Page

    @FocusState private var focusedElementID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PageView(
            page: page,
            isPageClosed: true,
            focusedElementID: $focusedElementID,
            hidesDate: true
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.folioPaper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 12, weight: .medium))
                        Text("Journal")
                            .font(.system(.subheadline, design: .serif))
                    }
                    .foregroundStyle(Color.folioInk)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(page.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.folioInk)
            }
        }
    }
}
