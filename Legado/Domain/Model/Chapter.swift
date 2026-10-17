import Foundation

/// 章节领域模型
public struct Chapter: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(bookUrl)_\(index)"
    }

    /// 章节正文 URL
    public var url: String
    /// 章节标题
    public var title: String
    /// 所属书籍 URL
    public var bookUrl: String
    /// 章节索引 (从 0 开始)
    public var index: Int
    /// 卷标或扩展标签
    public var tag: String?
    /// 是否已下载缓存至本地
    public var isCached: Bool

    public init(
        url: String,
        title: String,
        bookUrl: String,
        index: Int,
        tag: String? = nil,
        isCached: Bool = false) {
        self.url = url
        self.title = title
        self.bookUrl = bookUrl
        self.index = index
        self.tag = tag
        self.isCached = isCached
    }
}
