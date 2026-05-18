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

    @Environment(\.modelContext) private var modelContext
    @State private var keyboardHeight: CGFloat = 0
    /// Live centre of the dragging element, or nil when no drag is in
    /// flight. Drives the trash icon's reveal: it fades in only when
    /// the element nears the bottom delete strip.
    @State private var dragCentre: CGPoint? = nil
    /// Owns the AVAudioRecorder lifecycle for this page. Per-PageView
    /// so multiple pages don't share recorder state; recording is only
    /// meaningful for today's editor anyway.
    @State private var audioRecorder = AudioRecorder()

    private static let topContentInset: CGFloat = 40
    /// Reserved bottom strip that mirrors topContentInset. Covers the
    /// ToolbarView (HStack of five 44pt icons plus 12pt vertical
    /// padding = 68pt) plus a small margin so taps near the toolbar
    /// edge don't create text elements behind it.
    private static let bottomContentInset: CGFloat = 80
    private static let focusedElementBreath: CGFloat = 100
    /// Height of the bottom strip that counts as the delete zone.
    /// Drops here delete; drops elsewhere commit (and clamp).
    private static let bottomDeleteZone: CGFloat = 80
    /// Trash icon fades in when the dragging element's centre is within
    /// this distance of the bottom edge. Larger than bottomDeleteZone
    /// so the affordance appears before the user enters the zone.
    private static let trashRevealZone: CGFloat = 200
    /// Trash icon centres this many points above the bottom of the
    /// canvas — close to the edge so it visually anchors the delete
    /// strip rather than floating away from it.
    private static let trashBottomInset: CGFloat = 32

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
                        isPageClosed: isPageClosed,
                        canvasSize: geometry.size,
                        bottomDeleteZone: Self.bottomDeleteZone,
                        onDragChange: { centre in
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragCentre = centre
                            }
                        },
                        onDelete: { deleteTextElement(element) }
                    )
                    .offset(x: element.positionX, y: element.positionY)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }

                ForEach(page.voiceMemoElements) { memo in
                    VoiceMemoElementView(
                        element: memo,
                        isPageClosed: isPageClosed,
                        canvasSize: geometry.size,
                        bottomDeleteZone: Self.bottomDeleteZone,
                        onDragChange: { centre in
                            withAnimation(.easeOut(duration: 0.22)) {
                                dragCentre = centre
                            }
                        },
                        onDelete: { deleteVoiceMemo(memo) }
                    )
                    .offset(x: memo.positionX, y: memo.positionY)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }

                // Bottom toolbar per design.md §6.1. Hidden while an
                // element is being dragged so the trash icon below has
                // room.
                if dragCentre == nil {
                    VStack {
                        Spacer()
                        ToolbarView(
                            onVoicePressChange: { isPressing in
                                handleVoiceButton(
                                    isPressing: isPressing,
                                    canvasSize: geometry.size
                                )
                            },
                            isRecording: audioRecorder.isRecording
                        )
                    }
                }

                // Floating trash affordance. Reveals only when the
                // dragging element's centre approaches the bottom edge.
                // .allowsHitTesting(false) so the active drag gesture
                // keeps tracking the finger as it passes over the icon.
                if isTrashRevealed(for: geometry.size) {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.folioInk)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.folioInk.opacity(0.10)))
                        .position(trashCentre(for: geometry.size))
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .offset(y: canvasLift(viewportHeight: geometry.size.height))
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { event in
                        handleCanvasTap(at: event.location, canvasSize: geometry.size)
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
        .onDisappear {
            // If the user navigates away mid-recording, drop the
            // partial file rather than orphan it on disk.
            if audioRecorder.isRecording {
                audioRecorder.cancelRecording()
            }
        }
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

    /// Animated removal of a text element. ForEach picks up the
    /// relationship change and runs the .transition modifier on the
    /// child, giving the element a fade + shrink as it disappears.
    private func deleteTextElement(_ element: TextElement) {
        withAnimation(.easeOut(duration: 0.22)) {
            modelContext.delete(element)
        }
    }

    /// Same animated removal for voice memos. We delete the model row;
    /// the .m4a file on disk is left in Documents/voicememos/ for now
    /// (orphans accumulate slowly with no journaling-rate concern). A
    /// later pass can sweep unreferenced audio files.
    private func deleteVoiceMemo(_ memo: VoiceMemoElement) {
        withAnimation(.easeOut(duration: 0.22)) {
            modelContext.delete(memo)
        }
    }

    /// The toolbar voice button's press/release lifecycle: start on
    /// press, stop on release and place the resulting sticker at the
    /// top-centre of the page (user can drag it where they want).
    private func handleVoiceButton(isPressing: Bool, canvasSize: CGSize) {
        if isPressing {
            Task { @MainActor in
                await audioRecorder.startRecording()
            }
        } else {
            Task { @MainActor in
                guard let result = audioRecorder.stopRecording() else { return }
                createVoiceMemo(
                    canvasSize: canvasSize,
                    url: result.url,
                    duration: result.duration
                )
            }
        }
    }

    /// Inserts a freshly-recorded voice memo at the top centre of the
    /// canvas (just below the date header), draggable from there.
    private func createVoiceMemo(canvasSize: CGSize, url: URL, duration: TimeInterval) {
        let halfWidth: CGFloat = 90  // matches VoiceMemoElementView's estimatedHalfWidth
        let topY: CGFloat = 60       // below the date header, above the elements
        let memo = VoiceMemoElement(
            positionX: canvasSize.width / 2 - halfWidth,
            positionY: topY,
            audioFileURL: url,
            durationSeconds: duration
        )
        page.voiceMemoElements.append(memo)
        FolioHaptic.soft()
    }

    /// Where the trash icon sits, in canvas coords.
    private func trashCentre(for canvas: CGSize) -> CGPoint {
        CGPoint(x: canvas.width / 2, y: canvas.height - Self.trashBottomInset)
    }

    /// True when the live drag centre is within trashRevealZone of the
    /// bottom edge. The icon fades in/out via .transition on its `if`.
    private func isTrashRevealed(for canvas: CGSize) -> Bool {
        guard let centre = dragCentre else { return false }
        return centre.y > canvas.height - Self.trashRevealZone
    }

    /// Honours the chosen tap-while-editing rule (commit, do not create
    /// a new element on this tap). Creation is also suppressed entirely
    /// once midnight has passed on a still-open page (design.md §3.1)
    /// and inside the top/bottom inset strips (date header and toolbar).
    private func handleCanvasTap(at location: CGPoint, canvasSize: CGSize) {
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

        // Creation is gated by the top boundary (date header) and the
        // bottom boundary (toolbar). Taps in either strip silently no-op.
        guard location.y >= Self.topContentInset else { return }
        guard location.y <= canvasSize.height - Self.bottomContentInset else { return }

        let new = TextElement(positionX: location.x, positionY: location.y)
        page.textElements.append(new)
        focusedElementID = new.id
        FolioHaptic.soft()
    }
}
