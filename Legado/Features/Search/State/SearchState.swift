import Foundation

/// 搜索界面单一状态容器
public struct SearchState: ViewState, Equatable, Sendable {
    /// 当前输入搜索词
    public var query: String
    /// 是否处于搜索请求执行中
    public var isSearching: Bool
    /// 搜索完成进度比率 (0.0 ~ 1.0)
    public var searchProgress: Double
    /// 进度状态文字 (例如: 已完成 12/20 个书源)
    public var progressText: String
    /// 聚合去重后的搜索结果列表
    public var resultGroups: [SearchResultGroup]
    /// 最近搜索历史记录
    public var recentSearches: [String]
    /// 热门搜索推荐词
    public var hotKeywords: [String]
    /// 当前展开查看多源列表的分组 ID 集合
    public var expandedGroupIds: Set<String>
    /// 已经被加入书架的书籍 URL 集合
    public var addedBookUrls: Set<String>
    /// 错误提示
    public var errorMessage: String?

    public init(
        query: String = "",
        isSearching: Bool = false,
        searchProgress: Double = 0.0,
        progressText: String = "",
        resultGroups: [SearchResultGroup] = [],
        recentSearches: [String] = [],
        hotKeywords: [String] = ["诡秘之主", "道诡异仙", "剑来", "万族之劫", "大奉打更人", "宿命之环"],
        expandedGroupIds: Set<String> = [],
        addedBookUrls: Set<String> = [],
        errorMessage: String? = nil) {
        self.query = query
        self.isSearching = isSearching
        self.searchProgress = searchProgress
        self.progressText = progressText
        self.resultGroups = resultGroups
        self.recentSearches = recentSearches
        self.hotKeywords = hotKeywords
        self.expandedGroupIds = expandedGroupIds
        self.addedBookUrls = addedBookUrls
        self.errorMessage = errorMessage
    }
}
