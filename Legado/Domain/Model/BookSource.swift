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

/// 段评与章评规则 (对齐 Android Legado ReviewRule.kt)
public struct RuleReview: Codable, Equatable, Sendable {
    public var reviewUrl: String?
    public var avatarRule: String?
    public var contentRule: String?
    public var postTimeRule: String?
    public var reviewQuoteUrl: String?
    public var voteUpUrl: String?
    public var voteDownUrl: String?

    public init(
        reviewUrl: String? = nil,
        avatarRule: String? = nil,
        contentRule: String? = nil,
        postTimeRule: String? = nil,
        reviewQuoteUrl: String? = nil,
        voteUpUrl: String? = nil,
        voteDownUrl: String? = nil) {
        self.reviewUrl = reviewUrl
        self.avatarRule = avatarRule
        self.contentRule = contentRule
        self.postTimeRule = postTimeRule
        self.reviewQuoteUrl = reviewQuoteUrl
        self.voteUpUrl = voteUpUrl
        self.voteDownUrl = voteDownUrl
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
    public var ruleReview: RuleReview?

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
        ruleContent: RuleContent? = nil,
        ruleReview: RuleReview? = nil) {
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
        self.ruleReview = ruleReview
    }

    private enum CodingKeys: String, CodingKey {
        case bookSourceUrl
        case bookSourceName
        case bookSourceGroup
        case bookSourceType
        case bookUrlPattern
        case header
        case loginUrl
        case exploreUrl
        case searchUrl
        case weight
        case enabled
        case enabledExplore
        case customOrder
        case lastUpdateTime
        case bookSourceComment
        case ruleSearch
        case ruleExplore
        case ruleBookInfo
        case ruleToc
        case ruleContent
        case ruleReview
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bookSourceUrl = try container.decode(String.self, forKey: .bookSourceUrl)
        self.bookSourceName = try container.decode(String.self, forKey: .bookSourceName)
        self.bookSourceGroup = try container.decodeIfPresent(String.self, forKey: .bookSourceGroup)
        self.bookSourceType = container.decodeLenientInt(forKey: .bookSourceType)
        self.bookUrlPattern = try container.decodeIfPresent(String.self, forKey: .bookUrlPattern)
        self.header = try container.decodeIfPresent(String.self, forKey: .header)
        self.loginUrl = try container.decodeIfPresent(String.self, forKey: .loginUrl)
        self.exploreUrl = try container.decodeIfPresent(String.self, forKey: .exploreUrl)
        self.searchUrl = try container.decodeIfPresent(String.self, forKey: .searchUrl)
        self.weight = container.decodeLenientInt(forKey: .weight)
        self.enabled = container.decodeLenientBool(forKey: .enabled)
        self.enabledExplore = container.decodeLenientBool(forKey: .enabledExplore)
        self.customOrder = container.decodeLenientInt(forKey: .customOrder)
        self.lastUpdateTime = container.decodeLenientInt64(forKey: .lastUpdateTime)
        self.bookSourceComment = try container.decodeIfPresent(String.self, forKey: .bookSourceComment)
        self.ruleSearch = try container.decodeIfPresent(RuleSearch.self, forKey: .ruleSearch)
        self.ruleExplore = try container.decodeIfPresent(RuleExplore.self, forKey: .ruleExplore)
        self.ruleBookInfo = try container.decodeIfPresent(RuleBookInfo.self, forKey: .ruleBookInfo)
        self.ruleToc = try container.decodeIfPresent(RuleToc.self, forKey: .ruleToc)
        self.ruleContent = try container.decodeIfPresent(RuleContent.self, forKey: .ruleContent)
        self.ruleReview = try container.decodeIfPresent(RuleReview.self, forKey: .ruleReview)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookSourceUrl, forKey: .bookSourceUrl)
        try container.encode(bookSourceName, forKey: .bookSourceName)
        try container.encodeIfPresent(bookSourceGroup, forKey: .bookSourceGroup)
        try container.encodeIfPresent(bookSourceType, forKey: .bookSourceType)
        try container.encodeIfPresent(bookUrlPattern, forKey: .bookUrlPattern)
        try container.encodeIfPresent(header, forKey: .header)
        try container.encodeIfPresent(loginUrl, forKey: .loginUrl)
        try container.encodeIfPresent(exploreUrl, forKey: .exploreUrl)
        try container.encodeIfPresent(searchUrl, forKey: .searchUrl)
        try container.encodeIfPresent(weight, forKey: .weight)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(enabledExplore, forKey: .enabledExplore)
        try container.encodeIfPresent(customOrder, forKey: .customOrder)
        try container.encodeIfPresent(lastUpdateTime, forKey: .lastUpdateTime)
        try container.encodeIfPresent(bookSourceComment, forKey: .bookSourceComment)
        try container.encodeIfPresent(ruleSearch, forKey: .ruleSearch)
        try container.encodeIfPresent(ruleExplore, forKey: .ruleExplore)
        try container.encodeIfPresent(ruleBookInfo, forKey: .ruleBookInfo)
        try container.encodeIfPresent(ruleToc, forKey: .ruleToc)
        try container.encodeIfPresent(ruleContent, forKey: .ruleContent)
        try container.encodeIfPresent(ruleReview, forKey: .ruleReview)
    }
}

private extension KeyedDecodingContainer {
    func decodeLenientInt(forKey key: Key) -> Int? {
        if let val = try? decodeIfPresent(Int.self, forKey: key) {
            return val
        }
        if let str = try? decodeIfPresent(String.self, forKey: key) {
            return Int(str)
        }
        return nil
    }

    func decodeLenientInt64(forKey key: Key) -> Int64? {
        if let val = try? decodeIfPresent(Int64.self, forKey: key) {
            return val
        }
        if let str = try? decodeIfPresent(String.self, forKey: key) {
            return Int64(str)
        }
        return nil
    }

    func decodeLenientBool(forKey key: Key) -> Bool? {
        if let val = try? decodeIfPresent(Bool.self, forKey: key) {
            return val
        }
        if let intVal = try? decodeIfPresent(Int.self, forKey: key) {
            return intVal != 0
        }
        if let str = try? decodeIfPresent(String.self, forKey: key) {
            return str == "true" || str == "1"
        }
        return nil
    }
}
