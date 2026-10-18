import Foundation

/// 搜索规则
public struct RuleSearch: Codable, Equatable, Sendable {
    public var checkKeyWord: String?
    public var bookList: String?
    public var name: String?
    public var author: String?
    public var kind: String?
    public var wordCount: String?
    public var lastChapter: String?
    public var intro: String?
    public var coverUrl: String?
    public var bookUrl: String?

    public init(
        checkKeyWord: String? = nil,
        bookList: String? = nil,
        name: String? = nil,
        author: String? = nil,
        kind: String? = nil,
        wordCount: String? = nil,
        lastChapter: String? = nil,
        intro: String? = nil,
        coverUrl: String? = nil,
        bookUrl: String? = nil) {
        self.checkKeyWord = checkKeyWord
        self.bookList = bookList
        self.name = name
        self.author = author
        self.kind = kind
        self.wordCount = wordCount
        self.lastChapter = lastChapter
        self.intro = intro
        self.coverUrl = coverUrl
        self.bookUrl = bookUrl
    }
}

/// 发现规则
public struct RuleExplore: Codable, Equatable, Sendable {
    public var bookList: String?
    public var name: String?
    public var author: String?
    public var kind: String?
    public var wordCount: String?
    public var lastChapter: String?
    public var intro: String?
    public var coverUrl: String?
    public var bookUrl: String?

    public init(
        bookList: String? = nil,
        name: String? = nil,
        author: String? = nil,
        kind: String? = nil,
        wordCount: String? = nil,
        lastChapter: String? = nil,
        intro: String? = nil,
        coverUrl: String? = nil,
        bookUrl: String? = nil) {
        self.bookList = bookList
        self.name = name
        self.author = author
        self.kind = kind
        self.wordCount = wordCount
        self.lastChapter = lastChapter
        self.intro = intro
        self.coverUrl = coverUrl
        self.bookUrl = bookUrl
    }
}

/// 详情页规则
public struct RuleBookInfo: Codable, Equatable, Sendable {
    public var bookInfoInit: String?
    public var name: String?
    public var author: String?
    public var kind: String?
    public var wordCount: String?
    public var lastChapter: String?
    public var intro: String?
    public var coverUrl: String?
    public var tocUrl: String?
    public var canReName: String?

    public init(
        bookInfoInit: String? = nil,
        name: String? = nil,
        author: String? = nil,
        kind: String? = nil,
        wordCount: String? = nil,
        lastChapter: String? = nil,
        intro: String? = nil,
        coverUrl: String? = nil,
        tocUrl: String? = nil,
        canReName: String? = nil) {
        self.bookInfoInit = bookInfoInit
        self.name = name
        self.author = author
        self.kind = kind
        self.wordCount = wordCount
        self.lastChapter = lastChapter
        self.intro = intro
        self.coverUrl = coverUrl
        self.tocUrl = tocUrl
        self.canReName = canReName
    }

    private enum CodingKeys: String, CodingKey {
        case bookInfoInit = "init"
        case legacyBookInfoInit = "bookInfoInit"
        case name, author, kind, wordCount, lastChapter, intro, coverUrl, tocUrl, canReName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bookInfoInit = try container.decodeIfPresent(String.self, forKey: .bookInfoInit)
            ?? container.decodeIfPresent(String.self, forKey: .legacyBookInfoInit)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.author = try container.decodeIfPresent(String.self, forKey: .author)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.wordCount = try container.decodeIfPresent(String.self, forKey: .wordCount)
        self.lastChapter = try container.decodeIfPresent(String.self, forKey: .lastChapter)
        self.intro = try container.decodeIfPresent(String.self, forKey: .intro)
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        self.tocUrl = try container.decodeIfPresent(String.self, forKey: .tocUrl)
        self.canReName = try container.decodeIfPresent(String.self, forKey: .canReName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(bookInfoInit, forKey: .bookInfoInit)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(lastChapter, forKey: .lastChapter)
        try container.encodeIfPresent(intro, forKey: .intro)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
        try container.encodeIfPresent(tocUrl, forKey: .tocUrl)
        try container.encodeIfPresent(canReName, forKey: .canReName)
    }
}

/// 目录规则
public struct RuleToc: Codable, Equatable, Sendable {
    public var chapterList: String?
    public var chapterName: String?
    public var chapterUrl: String?
    public var isVip: String?
    public var updateTime: String?
    public var nextTocUrl: String?

    public init(
        chapterList: String? = nil,
        chapterName: String? = nil,
        chapterUrl: String? = nil,
        isVip: String? = nil,
        updateTime: String? = nil,
        nextTocUrl: String? = nil) {
        self.chapterList = chapterList
        self.chapterName = chapterName
        self.chapterUrl = chapterUrl
        self.isVip = isVip
        self.updateTime = updateTime
        self.nextTocUrl = nextTocUrl
    }
}

/// 正文规则
public struct RuleContent: Codable, Equatable, Sendable {
    public var content: String?
    public var nextContentUrl: String?
    public var sourceRegex: String?
    public var webJs: String?

    public init(
        content: String? = nil,
        nextContentUrl: String? = nil,
        sourceRegex: String? = nil,
        webJs: String? = nil) {
        self.content = content
        self.nextContentUrl = nextContentUrl
        self.sourceRegex = sourceRegex
        self.webJs = webJs
    }

    private enum CodingKeys: String, CodingKey {
        case content
        case nextContentUrl
        case sourceRegex
        case replaceRegex
        case webJs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decodeIfPresent(String.self, forKey: .content)
        self.nextContentUrl = try container.decodeIfPresent(String.self, forKey: .nextContentUrl)
        self.sourceRegex = try container.decodeIfPresent(String.self, forKey: .sourceRegex)
            ?? container.decodeIfPresent(String.self, forKey: .replaceRegex)
        self.webJs = try container.decodeIfPresent(String.self, forKey: .webJs)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(nextContentUrl, forKey: .nextContentUrl)
        try container.encodeIfPresent(sourceRegex, forKey: .sourceRegex)
        try container.encodeIfPresent(webJs, forKey: .webJs)
    }
}

/// Legado 3.0 书源核心领域模型
public struct BookSource: Identifiable, Codable, Equatable, Sendable {
    public var id: String {
        bookSourceUrl
    }

    public var bookSourceUrl: String
    public var bookSourceName: String
    public var bookSourceGroup: String?
    public var bookSourceType: Int?
    public var bookUrlPattern: String?
    public var header: String?
    public var loginUrl: String?
    public var exploreUrl: String?
    public var searchUrl: String?
    public var weight: Int?
    public var enabled: Bool?
    public var enabledExplore: Bool?
    public var customOrder: Int?
    public var lastUpdateTime: Int64?
    public var bookSourceComment: String?

    public var ruleSearch: RuleSearch?
    public var ruleExplore: RuleExplore?
    public var ruleBookInfo: RuleBookInfo?
    public var ruleToc: RuleToc?
    public var ruleContent: RuleContent?

    public init(
        bookSourceUrl: String,
        bookSourceName: String,
        bookSourceGroup: String? = nil,
        bookSourceType: Int? = 0,
        bookUrlPattern: String? = nil,
        header: String? = nil,
        loginUrl: String? = nil,
        exploreUrl: String? = nil,
        searchUrl: String? = nil,
        weight: Int? = 0,
        enabled: Bool? = true,
        enabledExplore: Bool? = true,
        customOrder: Int? = 0,
        lastUpdateTime: Int64? = nil,
        bookSourceComment: String? = nil,
        ruleSearch: RuleSearch? = nil,
        ruleExplore: RuleExplore? = nil,
        ruleBookInfo: RuleBookInfo? = nil,
        ruleToc: RuleToc? = nil,
        ruleContent: RuleContent? = nil) {
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceName = bookSourceName
        self.bookSourceGroup = bookSourceGroup
        self.bookSourceType = bookSourceType
        self.bookUrlPattern = bookUrlPattern
        self.header = header
        self.loginUrl = loginUrl
        self.exploreUrl = exploreUrl
        self.searchUrl = searchUrl
        self.weight = weight
        self.enabled = enabled
        self.enabledExplore = enabledExplore
        self.customOrder = customOrder
        self.lastUpdateTime = lastUpdateTime
        self.bookSourceComment = bookSourceComment
        self.ruleSearch = ruleSearch
        self.ruleExplore = ruleExplore
        self.ruleBookInfo = ruleBookInfo
        self.ruleToc = ruleToc
        self.ruleContent = ruleContent
    }
}
