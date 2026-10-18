import Foundation
import SwiftData

/// SwiftData 书签与笔记持久化实体
@Model
public final class BookmarkEntity {
    @Attribute(.unique) public var id: String
    public var time: Int64
    public var bookName: String
    public var bookAuthor: String
    public var bookUrl: String
    public var chapterIndex: Int
    public var chapterPos: Int
    public var chapterName: String
    public var bookText: String
    public var content: String

    public init(
        id: String,
        time: Int64,
        bookName: String,
        bookAuthor: String,
        bookUrl: String,
        chapterIndex: Int,
        chapterPos: Int,
        chapterName: String,
        bookText: String,
        content: String = "") {
        self.id = id
        self.time = time
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.bookUrl = bookUrl
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterName = chapterName
        self.bookText = bookText
        self.content = content
    }

    public convenience init(from domain: Bookmark) {
        self.init(
            id: domain.id,
            time: domain.time,
            bookName: domain.bookName,
            bookAuthor: domain.bookAuthor,
            bookUrl: domain.bookUrl,
            chapterIndex: domain.chapterIndex,
            chapterPos: domain.chapterPos,
            chapterName: domain.chapterName,
            bookText: domain.bookText,
            content: domain.content)
    }

    public func toDomain() -> Bookmark {
        Bookmark(
            time: time,
            bookName: bookName,
            bookAuthor: bookAuthor,
            bookUrl: bookUrl,
            chapterIndex: chapterIndex,
            chapterPos: chapterPos,
            chapterName: chapterName,
            bookText: bookText,
            content: content)
    }
}
