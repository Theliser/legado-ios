import Foundation

/// 搜索页面用户交互意图
public enum SearchIntent: ViewIntent, Equatable, Sendable {
    /// 搜索输入框文本变化
    case updateQuery(String)
    /// 提交搜索
    case submitSearch(String)
    /// 取消当前搜索
    case cancelSearch
    /// 点击历史搜索或热门搜索标签
    case selectKeyword(String)
    /// 清除所有历史搜索记录
    case clearRecentSearches
    /// 展开或折叠某聚合书籍的书源列表
    case toggleExpandGroup(String)
    /// 将指定书源项加入书架
    case addToBookshelf(SearchResult)
}

/// 搜索一次性副作用
public enum SearchEffect: ViewEffect, Equatable, Sendable {
    case showToast(String)
    case hapticFeedback
}
