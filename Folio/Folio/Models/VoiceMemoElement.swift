import Foundation
import SwiftData

/// A recorded voice memo placed on a page. Per design.md §5.2, these
/// render as polaroid-style stickers with a rendered waveform; for v0
/// the rendering itself is a placeholder until slice 9.
///
/// audioFileURL points at an .m4a file inside the app's Documents
/// directory (subfolder voicememos/). Storing the full URL works for
/// now; we'll refactor to a filename + reconstructed URL when iCloud
/// sync arrives, since URLs can drift across storage backends.
@Model
final class VoiceMemoElement {
    var id: UUID

    // Spatial state — primitives for CloudKit-friendliness, mirroring
    // TextElement. See TextElement for the rationale.
    var positionX: Double
    var positionY: Double
    var rotationRadians: Double
    var scale: Double
    var zIndex: Int

    // Audio payload
    var audioFileURL: URL
    var durationSeconds: Double
    /// Pre-rendered amplitude samples used to draw the waveform sticker.
    /// Empty until slice 9 wires the AVAudioFile-based generation.
    var waveformSamples: [Double]

    var createdAt: Date

    /// Back-reference to the owning page. SwiftData uses this to wire
    /// the inverse of Page.voiceMemoElements.
    var page: Page?

    init(
        positionX: Double,
        positionY: Double,
        audioFileURL: URL,
        durationSeconds: Double,
        waveformSamples: [Double] = []
    ) {
        self.id = UUID()
        self.positionX = positionX
        self.positionY = positionY
        self.rotationRadians = 0
        self.scale = 1
        self.zIndex = 0
        self.audioFileURL = audioFileURL
        self.durationSeconds = durationSeconds
        self.waveformSamples = waveformSamples
        self.createdAt = Date()
    }
}
