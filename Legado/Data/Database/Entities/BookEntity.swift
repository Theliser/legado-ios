import Foundation
import SwiftData

/// SwiftData 书籍实体
@Model
public final class BookEntity {
    @Attribute(.unique) public var bookUrl: String
    public var tocUrl: String
    public var origin: String
    public var originName: String
    public var name: String
    public var author: String
    public var kind: String?
    public var coverUrl: String?
    public var intro: String?
    public var latestChapterTitle: String?
    public var latestChapterTime: Int64
    public var durChapterTitle: String?
    public var durChapterIndex: Int
    public var durChapterPos: Int
    public var durChapterTime: Int64
    public var wordCount: String?
    public var customOrder: Int
    public var totalChapterNum: Int
    public var groupName: String?

    public init(
        bookUrl: String,
        tocUrl: String,
        origin: String,
        originName: String,
        name: String,
        author: String,
        kind: String? = nil,
        coverUrl: String? = nil,
        intro: String? = nil,
        latestChapterTitle: String? = nil,
        latestChapterTime: Int64 = 0,
        durChapterTitle: String? = nil,
        durChapterIndex: Int = 0,
        durChapterPos: Int = 0,
        durChapterTime: Int64 = 0,
        wordCount: String? = nil,
        customOrder: Int = 0,
        totalChapterNum: Int = 0,
        groupName: String? = nil) {
        self.bookUrl = bookUrl
        self.tocUrl = tocUrl
        self.origin = origin
        self.originName = originName
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.intro = intro
        self.latestChapterTitle = latestChapterTitle
        self.latestChapterTime = latestChapterTime
        self.durChapterTitle = durChapterTitle
        self.durChapterIndex = durChapterIndex
        self.durChapterPos = durChapterPos
        self.durChapterTime = durChapterTime
        self.wordCount = wordCount
        self.customOrder = customOrder
        self.totalChapterNum = totalChapterNum
        self.groupName = groupName
    }

    public convenience init(from domain: Book) {
        self.init(
            bookUrl: domain.bookUrl,
            tocUrl: domain.tocUrl,
            origin: domain.origin,
            originName: domain.originName,
            name: domain.name,
            author: domain.author,
            kind: domain.kind,
            coverUrl: domain.coverUrl,
            intro: domain.intro,
            latestChapterTitle: domain.latestChapterTitle,
            latestChapterTime: domain.latestChapterTime,
            durChapterTitle: domain.durChapterTitle,
            durChapterIndex: domain.durChapterIndex,
            durChapterPos: domain.durChapterPos,
            durChapterTime: domain.durChapterTime,
            wordCount: domain.wordCount,
            customOrder: domain.order,
            totalChapterNum: domain.totalChapterNum,
            groupName: domain.groupName)
    }

    public func toDomain() -> Book {
        Book(
            bookUrl: bookUrl,
            tocUrl: tocUrl,
            origin: origin,
            originName: originName,
            name: name,
            author: author,
            kind: kind,
            coverUrl: coverUrl,
            intro: intro,
            latestChapterTitle: latestChapterTitle,
            latestChapterTime: latestChapterTime,
            durChapterTitle: durChapterTitle,
            durChapterIndex: durChapterIndex,
            durChapterPos: durChapterPos,
            durChapterTime: durChapterTime,
            wordCount: wordCount,
            order: customOrder,
            totalChapterNum: totalChapterNum,
            groupName: groupName)
    }
}
