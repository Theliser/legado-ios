import Foundation

/// 发现分类与排行榜项领域模型
public struct ExploreCategory: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(sourceUrl)_\(title)_\(categoryUrl)"
    }

    /// 归属书源 URL
    public let sourceUrl: String
    /// 归属书源名称
    public let sourceName: String
    /// 分类或榜单标题 (如 "玄幻奇幻"、"月票榜")
    public let title: String
    /// 分类页面 URL (通常包含 {{page}} 宏)
    public let categoryUrl: String

    public init(
        sourceUrl: String,
        sourceName: String,
        title: String,
        categoryUrl: String) {
        self.sourceUrl = sourceUrl
        self.sourceName = sourceName
        self.title = title
        self.categoryUrl = categoryUrl
    }
}
