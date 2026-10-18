import Foundation

/// 正文全文搜索命中条目
public struct BookSearchMatch: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(chapterIndex)_\(matchOffset)"
    }

    /// 所属章节索引
    public let chapterIndex: Int
    /// 所属章节标题
    public let chapterTitle: String
    /// 上下文摘录片段 (包含前后文字)
    public let snippet: String
    /// 关键词在整章中的字符偏移
    public let matchOffset: Int
    /// 匹配关键词长度
    public let matchLength: Int

    public init(
        chapterIndex: Int,
        chapterTitle: String,
        snippet: String,
        matchOffset: Int,
        matchLength: Int) {
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.snippet = snippet
        self.matchOffset = matchOffset
        self.matchLength = matchLength
    }
}
