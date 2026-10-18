import Foundation

/// 换源候选书源条目模型
public struct ChangeSourceCandidate: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(origin)_\(bookUrl)"
    }

    /// 书源地址
    public let origin: String
    /// 书源名称
    public let originName: String
    /// 该书源下的书籍详情页地址
    public let bookUrl: String
    /// 书名
    public let name: String
    /// 作者
    public let author: String
    /// 最新章节标题
    public let latestChapterTitle: String?
    /// 封面图片地址
    public let coverUrl: String?
    /// 搜索响应耗时 (毫秒)
    public let elapsedMs: Int
    /// 是否为当前正在使用的书源
    public let isCurrent: Bool

    public init(
        origin: String,
        originName: String,
        bookUrl: String,
        name: String,
        author: String,
        latestChapterTitle: String? = nil,
        coverUrl: String? = nil,
        elapsedMs: Int = 0,
        isCurrent: Bool = false) {
        self.origin = origin
        self.originName = originName
        self.bookUrl = bookUrl
        self.name = name
        self.author = author
        self.latestChapterTitle = latestChapterTitle
        self.coverUrl = coverUrl
        self.elapsedMs = elapsedMs
        self.isCurrent = isCurrent
    }
}
