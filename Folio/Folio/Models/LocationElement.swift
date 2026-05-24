import Foundation
import SwiftData

/// A location pinned on a page. Per design.md §5.4 renders as a sticker
/// with the place name and a small pin glyph. displayName is set by
/// the auto-reverse-geocode at creation time and can be overridden by
/// the user — "the cafe on the corner" being more honest than the
/// official place name.
@Model
final class LocationElement {
    var id: UUID

    // Spatial state — primitives for CloudKit-friendliness, mirroring
    // the other element types.
    var positionX: Double
    var positionY: Double
    var rotationRadians: Double
    var scale: Double
    var zIndex: Int

    // Location data
    var latitude: Double
    var longitude: Double
    /// Human-readable name. Initially the reverse-geocode result; the
    /// user can edit it to anything they prefer.
    var displayName: String

    var createdAt: Date

    /// Back-reference to the owning page. Inverse of Page.locationElements.
    var page: Page?

    init(
        positionX: Double,
        positionY: Double,
        latitude: Double,
        longitude: Double,
        displayName: String
    ) {
        self.id = UUID()
        self.positionX = positionX
        self.positionY = positionY
        self.rotationRadians = 0
        self.scale = 1
        self.zIndex = 0
        self.latitude = latitude
        self.longitude = longitude
        self.displayName = displayName
        self.createdAt = Date()
    }
}
