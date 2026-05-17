import SwiftUI
import SwiftData

/// Read-only full-page display of a closed page from the journal.
/// Wraps PageView with isPageClosed=true so every interaction path
/// (tap-create, drag, tap-to-refocus) is suppressed. The date stays
/// inside the page (where the editor draws it) rather than being
/// duplicated in the nav title — back navigation is provided by the
/// enclosing NavigationStack.
struct JournalPageView: View {
    let page: Page

    @FocusState private var focusedElementID: UUID?

    var body: some View {
        PageView(
            page: page,
            isPageClosed: true,
            focusedElementID: $focusedElementID
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}
