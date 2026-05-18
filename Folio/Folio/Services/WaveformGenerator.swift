import AVFoundation
import Foundation

/// Reads a recorded audio file and produces a short array of amplitude
/// samples suitable for drawing the abstract waveform inside a voice
/// memo sticker (design.md §5.2).
///
/// The output is `targetCount` doubles in [0, 1]. We bucket all the
/// audio frames into `targetCount` windows and emit the peak absolute
/// amplitude per window — that gives the abstract "vertical lines whose
/// heights map to amplitude" look without trying to preserve every
/// sample.
enum WaveformGenerator {
    /// Generate a downsampled-peak waveform from the audio file at url.
    /// Returns an empty array if the file can't be read.
    static func generate(from url: URL, targetCount: Int = 40) -> [Double] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }

        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return [] }

        do {
            try file.read(into: buffer)
        } catch {
            return []
        }

        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let totalFrames = Int(buffer.frameLength)
        guard totalFrames > 0 else { return [] }

        let bucketSize = max(1, totalFrames / targetCount)
        var samples: [Double] = []
        samples.reserveCapacity(targetCount)

        for i in 0..<targetCount {
            let start = i * bucketSize
            let end = min(start + bucketSize, totalFrames)
            guard start < end else { break }
            var peak: Float = 0
            for j in start..<end {
                let v = abs(channelData[j])
                if v > peak { peak = v }
            }
            samples.append(Double(peak))
        }

        return samples
    }
}
