import Foundation

/// 书籍详情页规则 (对齐 Android Legado BookInfoRule.kt)
public struct BookInfoRule: Codable, Equatable, Sendable {
    public var bookInfoInit: String?
    public var name: String?
    public var author: String?
    public var intro: String?
    public var kind: String?
    public var lastChapter: String?
    public var updateTime: String?
    public var coverUrl: String?
    public var tocUrl: String?
    public var wordCount: String?
    public var canReName: String?
    public var downloadUrls: String?
    public var relatedBooks: String?

    public init(
        bookInfoInit: String? = nil,
        name: String? = nil,
        author: String? = nil,
        intro: String? = nil,
        kind: String? = nil,
        lastChapter: String? = nil,
        updateTime: String? = nil,
        coverUrl: String? = nil,
        tocUrl: String? = nil,
        wordCount: String? = nil,
        canReName: String? = nil,
        downloadUrls: String? = nil,
        relatedBooks: String? = nil) {
        self.bookInfoInit = bookInfoInit
        self.name = name
        self.author = author
        self.intro = intro
        self.kind = kind
        self.lastChapter = lastChapter
        self.updateTime = updateTime
        self.coverUrl = coverUrl
        self.tocUrl = tocUrl
        self.wordCount = wordCount
        self.canReName = canReName
        self.downloadUrls = downloadUrls
        self.relatedBooks = relatedBooks
    }

    private enum CodingKeys: String, CodingKey {
        case bookInfoInit = "init"
        case legacyBookInfoInit = "bookInfoInit"
        case name
        case author
        case intro
        case kind
        case lastChapter
        case updateTime
        case coverUrl
        case tocUrl
        case wordCount
        case canReName
        case downloadUrls
        case relatedBooks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bookInfoInit = try container.decodeIfPresent(String.self, forKey: .bookInfoInit)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBookInfoInit)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.intro = try container.decodeIfPresent(String.self, forKey: .intro)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.lastChapter = try container.decodeIfPresent(String.self, forKey: .lastChapter)
        self.updateTime = try container.decodeIfPresent(String.self, forKey: .updateTime)
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        self.tocUrl = try container.decodeIfPresent(String.self, forKey: .tocUrl)
        self.wordCount = try container.decodeIfPresent(String.self, forKey: .wordCount)
        self.canReName = try container.decodeIfPresent(String.self, forKey: .canReName)
        self.downloadUrls = try container.decodeIfPresent(String.self, forKey: .downloadUrls)
        self.relatedBooks = try container.decodeIfPresent(String.self, forKey: .relatedBooks)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(bookInfoInit, forKey: .bookInfoInit)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(intro, forKey: .intro)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(lastChapter, forKey: .lastChapter)
        try container.encodeIfPresent(updateTime, forKey: .updateTime)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
        try container.encodeIfPresent(tocUrl, forKey: .tocUrl)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(canReName, forKey: .canReName)
        try container.encodeIfPresent(downloadUrls, forKey: .downloadUrls)
        try container.encodeIfPresent(relatedBooks, forKey: .relatedBooks)
    }
}

public typealias RuleBookInfo = BookInfoRule
