import SwiftUI
import SwiftData

/// The spatial canvas for one Page. Layout + manipulation only — focus
/// state lives in ContentView (so the rollover orchestrator has direct
/// access), and the commit-on-focus-drop logic lives there too.
///
/// Keyboard avoidance is handled manually: SwiftUI's automatic avoidance
/// under-shifts when content is absolutely positioned with `.offset`, so
/// we observe keyboard notifications directly and lift the canvas just
/// enough to keep the focused element above the keyboard.
struct PageView: View {
    let page: Page
    /// True when the page belongs to a day before today. Suppresses
    /// new-element creation, drag, and tap-to-refocus — see design.md
    /// §3.1 quiet completion clarification. The currently-focused
    /// element can still finish input.
    let isPageClosed: Bool
    @FocusState.Binding var focusedElementID: UUID?
    /// Callback invoked when the user taps the journal icon. nil means
    /// no icon is rendered — used by JournalPageView, which displays a
    /// closed page from inside the journal itself.
    var onShowJournal: (() -> Void)? = nil
    /// When true, the page's date header is not rendered inside the
    /// canvas — the caller (e.g. JournalPageView) places it elsewhere
    /// (the nav toolbar, inline with the back button).
    var hidesDate: Bool = false

    @State private var keyboardHeight: CGFloat = 0

    private static let topContentInset: CGFloat = 40
    private static let focusedElementBreath: CGFloat = 100

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.folioPaper

                if !hidesDate {
                    Text(page.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.folioInk)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }

                if let onShowJournal {
                    Button {
                        // Commit any focused element first; ContentView's
                        // .onChange handler picks up the focus drop and
                        // runs the commit + rollover routine.
                        focusedElementID = nil
                        onShowJournal()
                    } label: {
                        Image(systemName: "book.closed")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.folioInk)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .padding(.top, 4)
                    .padding(.leading, 4)
                }

                ForEach(page.textElements) { element in
                    TextElementView(
                        element: element,
                        focusedElementID: $focusedElementID,
                        isPageClosed: isPageClosed
                    )
                    .offset(x: element.positionX, y: element.positionY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .offset(y: canvasLift(viewportHeight: geometry.size.height))
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        handleCanvasTap(at: event.location)
                    }
            )
        }
        .background(Color.folioPaper.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        .animation(.easeOut(duration: 0.25), value: focusedElementID)
    }

    /// How many points to lift the canvas so the focused element stays
    /// visible above the keyboard. Zero when no keyboard or no focused
    /// element, or when the element is already comfortably visible.
    private func canvasLift(viewportHeight: CGFloat) -> CGFloat {
        guard keyboardHeight > 0,
              let id = focusedElementID,
              let element = page.textElements.first(where: { $0.id == id })
        else { return 0 }

        let visibleHeight = viewportHeight - keyboardHeight
        let targetVisibleBottom = element.positionY + Self.focusedElementBreath
        let overhang = targetVisibleBottom - visibleHeight
        return overhang > 0 ? -overhang : 0
    }

    /// Honours the chosen tap-while-editing rule (commit, do not create
    /// a new element on this tap). Creation is also suppressed entirely
    /// once midnight has passed on a still-open page (design.md §3.1).
    private func handleCanvasTap(at location: CGPoint) {
        // Any canvas tap commits an in-progress edit, regardless of
        // where on the page it lands. This is the path by which a
        // post-midnight quiet completion happens — user taps outside,
        // focus drops, ContentView commits and runs the rollover.
        if focusedElementID != nil {
            focusedElementID = nil
            return
        }

        // No new elements after midnight, even on a still-open page.
        guard !isPageClosed else { return }

        // Creation is gated by the top boundary — the date header sits
        // there and should not be writable over.
        guard location.y >= Self.topContentInset else { return }

        let new = TextElement(positionX: location.x, positionY: location.y)
        page.textElements.append(new)
        focusedElementID = new.id
        FolioHaptic.soft()
    }
}
