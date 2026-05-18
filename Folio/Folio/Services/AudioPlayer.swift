import AVFoundation
import Foundation

/// Plays back voice memos. Mirrors AudioRecorder's shape — @Observable
/// wrapper around AVAudioPlayer, owns the audio-session lifecycle for
/// playback (.playback category). Single-player semantics: starting a
/// new memo stops any currently-playing one, so we never mix audio.
///
/// Progress is polled at ~20Hz via a Task while playback is active; the
/// VoiceMemoElementView reads `progress` to colour-in the waveform bars.
@Observable
final class AudioPlayer {
    /// Id of the voice memo currently playing, nil when stopped.
    private(set) var playingElementID: UUID?

    /// Playback progress as a fraction in [0, 1], drives the waveform's
    /// played-vs-unplayed coloring.
    private(set) var progress: Double = 0

    private var player: AVAudioPlayer?
    private var pollingTask: Task<Void, Never>?

    func isPlaying(_ memo: VoiceMemoElement) -> Bool {
        playingElementID == memo.id
    }

    @MainActor
    func toggle(_ memo: VoiceMemoElement) {
        if playingElementID == memo.id {
            FolioHaptic.soft()
            stop()
        } else {
            play(memo)
        }
    }

    @MainActor
    func play(_ memo: VoiceMemoElement) {
        // Single-player: stop whatever's currently going before we start.
        stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let newPlayer = try AVAudioPlayer(contentsOf: memo.audioFileURL)
            newPlayer.prepareToPlay()
            guard newPlayer.play() else { return }

            self.player = newPlayer
            self.playingElementID = memo.id
            self.progress = 0

            FolioHaptic.soft()
            startProgressPolling()
        } catch {
            print("AudioPlayer: failed to play \(memo.audioFileURL.lastPathComponent) — \(error)")
        }
    }

    @MainActor
    func stop() {
        guard playingElementID != nil else { return }
        player?.stop()
        player = nil
        playingElementID = nil
        progress = 0
        pollingTask?.cancel()
        pollingTask = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Polls AVAudioPlayer.currentTime at ~20Hz to drive the waveform
    /// progress overlay. Also detects natural end-of-playback (when
    /// player.isPlaying flips to false on its own) and stops cleanly.
    private func startProgressPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, let player = self.player, self.playingElementID != nil else {
                    return
                }
                if player.isPlaying {
                    self.progress = player.duration > 0
                        ? player.currentTime / player.duration
                        : 0
                } else {
                    // Audio finished naturally. Snap progress to 1 for a
                    // beat, then clean up.
                    self.progress = 1
                    self.stop()
                    return
                }
            }
        }
    }
}
