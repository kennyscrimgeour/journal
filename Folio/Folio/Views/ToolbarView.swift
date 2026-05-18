import SwiftUI

/// The bottom toolbar described in design.md §6.1 — five icons for the
/// five element types. For slice 8 only the voice button is active;
/// the others are rendered at reduced opacity as placeholders so the
/// full row's spacing and visual weight can be evaluated now.
///
/// "Visually quiet when no element is being placed or edited" per §6.1:
/// the toolbar uses ink-on-clear icons, no surrounding chrome, so it
/// doesn't compete with the page.
struct ToolbarView: View {
    /// Fires while the voice button is held down. Bool = true on press,
    /// false on release. Wiring to AudioRecorder comes in slice 8c.
    let onVoicePressChange: (Bool) -> Void

    /// Visual feedback for when the voice button is mid-recording.
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 28) {
            placeholderIcon("textformat")
            voiceButton
            placeholderIcon("photo")
            placeholderIcon("location")
            placeholderIcon("star.square")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
    }

    private var voiceButton: some View {
        Image(systemName: isRecording ? "waveform.circle.fill" : "waveform.circle")
            .font(.system(size: 24))
            .foregroundStyle(isRecording ? Color.red.opacity(0.8) : Color.folioInk)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .gesture(
                // minimumDistance: 0 fires on touch-down, not after a
                // movement threshold — exactly the tap-and-hold semantic.
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording { onVoicePressChange(true) }
                    }
                    .onEnded { _ in
                        onVoicePressChange(false)
                    }
            )
    }

    /// Icons for the not-yet-implemented element types. Rendered with
    /// the same size and weight as the active voice icon, just at low
    /// opacity, so the toolbar's eventual filled-in state is visible.
    private func placeholderIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22))
            .foregroundStyle(Color.folioInk.opacity(0.25))
            .frame(width: 44, height: 44)
    }
}
