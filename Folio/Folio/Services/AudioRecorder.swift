import AVFoundation
import Foundation

/// Wraps AVAudioRecorder for Folio's voice-memo flow. Designed for the
/// tap-and-hold model: startRecording on press, stopRecording on release.
/// Recordings are written to Documents/voicememos/{uuid}.m4a; the URL
/// is what gets stored on the VoiceMemoElement.
///
/// 60-second cap per design.md §5.2: AVAudioRecorder.record(forDuration:)
/// stops the underlying recorder automatically at the deadline. On
/// release we calculate the elapsed time and clamp to 60s.
///
/// @Observable so SwiftUI views can react to isRecording for visual
/// feedback (e.g. the toolbar voice icon changing colour while held).
@Observable
final class AudioRecorder {
    private(set) var isRecording = false
    private var recorder: AVAudioRecorder?
    private var startTime: Date?

    /// Per design.md §5.2: "Maximum recording length: 60 seconds."
    static let maxDuration: TimeInterval = 60

    /// Documents/voicememos/ created on first access.
    private static var voiceMemosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("voicememos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Checks AVAudioApplication.shared.recordPermission, requesting if
    /// undetermined. Returns true if recording is allowed.
    @discardableResult
    func ensurePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    /// Starts a new recording. Configures the audio session, creates a
    /// fresh .m4a file, and kicks off AVAudioRecorder with a 60s ceiling.
    /// Returns the destination URL on success; nil if permission denied,
    /// already recording, or the recorder failed to start.
    @MainActor
    @discardableResult
    func startRecording() async -> URL? {
        guard !isRecording else { return nil }
        guard await ensurePermission() else { return nil }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = Self.voiceMemosDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            let started = newRecorder.record(forDuration: Self.maxDuration)
            guard started else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            self.recorder = newRecorder
            self.startTime = Date()
            self.isRecording = true
            return url
        } catch {
            print("AudioRecorder: failed to start — \(error)")
            return nil
        }
    }

    /// Stops the in-flight recording and returns the resulting file URL
    /// plus the elapsed duration (clamped to 60s). Returns nil if no
    /// recording was active.
    @MainActor
    @discardableResult
    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder else { return nil }

        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let duration = min(elapsed, Self.maxDuration)
        let url = recorder.url

        recorder.stop()
        self.recorder = nil
        self.startTime = nil
        self.isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        return (url, duration)
    }

    /// Stops recording without producing a usable result and deletes the
    /// partial file. Used when the user navigates away mid-recording, so
    /// we don't leave orphan files in Documents/voicememos.
    @MainActor
    func cancelRecording() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        try? FileManager.default.removeItem(at: url)

        self.recorder = nil
        self.startTime = nil
        self.isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
