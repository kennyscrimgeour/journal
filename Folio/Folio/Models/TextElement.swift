import Foundation
import SwiftData

/// A typed-text element placed on a page. Spatial state is stored as
/// primitives (Double / Int) so CloudKit sync remains uncomplicated
/// when we add it later — CloudKit doesn't love custom value types.
@Model
final class TextElement {
    var id: UUID

    // Spatial state. All five elements will share these, so we'll lift
    // them into a protocol or base type once we have a second element.
    var positionX: Double
    var positionY: Double
    var rotationRadians: Double
    var scale: Double
    var zIndex: Int

    // Content
    var text: String
    var fontName: String
    var fontSize: Double

    var createdAt: Date

    /// Back-reference to the owning page. Declared so SwiftData can wire
    /// the inverse relationship from Page.textElements.
    var page: Page?

    init(
        text: String = "",
        positionX: Double,
        positionY: Double,
        fontName: String = "System",
        fontSize: Double = 18
    ) {
        self.id = UUID()
        self.positionX = positionX
        self.positionY = positionY
        self.rotationRadians = 0
        self.scale = 1
        self.zIndex = 0
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.createdAt = Date()
    }
}
