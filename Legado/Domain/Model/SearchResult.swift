import Foundation

/// 单个书源搜索命中的书籍项
public struct SearchResult: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(origin)_\(bookUrl)"
    }

    /// 详情页地址
    public var bookUrl: String
    /// 书源唯一标识 (URL)
    public var origin: String
    /// 书源名称
    public var originName: String
    /// 书源排序权重
    public var originOrder: Int
    /// 书名
    public var name: String
    /// 作者
    public var author: String
    /// 分类标签
    public var kind: String?
    /// 封面图 URL
    public var coverUrl: String?
    /// 简介
    public var intro: String?
    /// 最新章节标题
    public var latestChapterTitle: String?
    /// 目录页 URL
    public var tocUrl: String
    /// 字数描述
    public var wordCount: String?
    /// 搜索响应耗时 (毫秒)
    public var responseTimeMs: Int

    public init(
        bookUrl: String,
        origin: String,
        originName: String,
        originOrder: Int = 0,
        name: String,
        author: String,
        kind: String? = nil,
        coverUrl: String? = nil,
        intro: String? = nil,
        latestChapterTitle: String? = nil,
        tocUrl: String = "",
        wordCount: String? = nil,
        responseTimeMs: Int = 0) {
        self.bookUrl = bookUrl
        self.origin = origin
        self.originName = originName
        self.originOrder = originOrder
        self.name = name
        self.author = author
        self.kind = kind
        self.coverUrl = coverUrl
        self.intro = intro
        self.latestChapterTitle = latestChapterTitle
        self.tocUrl = tocUrl
        self.wordCount = wordCount
        self.responseTimeMs = responseTimeMs
    }
}

/// 聚合去重后的搜索分组（同名+同作者汇聚多书源）
public struct SearchResultGroup: Identifiable, Hashable, Sendable {
    public var id: String {
        "\(name)_\(author)"
    }

    public var name: String
    public var author: String
    public var coverUrl: String?
    public var intro: String?
    public var kind: String?
    public var latestChapterTitle: String?
    public var sources: [SearchResult]

    public init(
        name: String,
        author: String,
        coverUrl: String? = nil,
        intro: String? = nil,
        kind: String? = nil,
        latestChapterTitle: String? = nil,
        sources: [SearchResult] = []) {
        self.name = name
        self.author = author
        self.coverUrl = coverUrl
        self.intro = intro
        self.kind = kind
        self.latestChapterTitle = latestChapterTitle
        self.sources = sources
    }
}
