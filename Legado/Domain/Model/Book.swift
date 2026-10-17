import Foundation

/// 书籍领域模型（纯业务实体，不依赖存储框架与 UI）
public struct Book: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        bookUrl
    }

    /// 书籍详情页完整 URL 或本地文件唯一路径
    public var bookUrl: String
    /// 目录页完整 URL
    public var tocUrl: String
    /// 书源 URL 或特殊标识 (如 local)
    public var origin: String
    /// 书源名称
    public var originName: String
    /// 书名
    public var name: String
    /// 作者
    public var author: String
    /// 分类标签 (以空格或逗号分隔)
    public var kind: String?
    /// 封面图片 URL
    public var coverUrl: String?
    /// 简介
    public var intro: String?
    /// 最新章节标题
    public var latestChapterTitle: String?
    /// 最新章节更新时间戳 (毫秒)
    public var latestChapterTime: Int64
    /// 当前阅读章节标题
    public var durChapterTitle: String?
    /// 当前阅读章节索引 (0-based)
    public var durChapterIndex: Int
    /// 当前阅读章节内字符偏移量
    public var durChapterPos: Int
    /// 最近阅读时间戳 (毫秒)
    public var durChapterTime: Int64
    /// 字数描述 (如 120万字)
    public var wordCount: String?
    /// 书架排序权重
    public var order: Int
    /// 总章节数
    public var totalChapterNum: Int

    public init(
        bookUrl: String,
        tocUrl: String = "",
        origin: String = "local",
        originName: String = "",
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
        order: Int = 0,
        totalChapterNum: Int = 0) {
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
        self.order = order
        self.totalChapterNum = totalChapterNum
    }
}
