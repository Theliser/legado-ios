import Foundation
import SwiftData

/// SwiftData 章节实体
@Model
public final class ChapterEntity {
    @Attribute(.unique) public var id: String
    public var url: String
    public var title: String
    public var bookUrl: String
    public var index: Int
    public var tag: String?
    public var isCached: Bool

    public init(
        id: String,
        url: String,
        title: String,
        bookUrl: String,
        index: Int,
        tag: String? = nil,
        isCached: Bool = false) {
        self.id = id
        self.url = url
        self.title = title
        self.bookUrl = bookUrl
        self.index = index
        self.tag = tag
        self.isCached = isCached
    }

    public convenience init(from domain: Chapter) {
        self.init(
            id: domain.id,
            url: domain.url,
            title: domain.title,
            bookUrl: domain.bookUrl,
            index: domain.index,
            tag: domain.tag,
            isCached: domain.isCached)
    }

    public func toDomain() -> Chapter {
        Chapter(
            url: url,
            title: title,
            bookUrl: bookUrl,
            index: index,
            tag: tag,
            isCached: isCached)
    }
}
