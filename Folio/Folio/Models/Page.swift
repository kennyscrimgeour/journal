import Foundation
import SwiftData

/// One day's page. Created at the start of its calendar day, closed at local
/// midnight. Once `closedAt` is set, the page is read-only forever.
@Model
final class Page {
    var id: UUID
    /// The calendar day this page represents, normalised to start-of-day.
    /// Used as the page's identity in the archive.
    var date: Date
    var createdAt: Date
    /// `nil` while the page is active. Set the moment the page closes;
    /// from then on the page must not be modified.
    var closedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \TextElement.page)
    var textElements: [TextElement]

    @Relationship(deleteRule: .cascade, inverse: \VoiceMemoElement.page)
    var voiceMemoElements: [VoiceMemoElement]

    @Relationship(deleteRule: .cascade, inverse: \LocationElement.page)
    var locationElements: [LocationElement]

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.createdAt = Date()
        self.closedAt = nil
        self.textElements = []
        self.voiceMemoElements = []
        self.locationElements = []
    }

    var isClosed: Bool { closedAt != nil }
}
