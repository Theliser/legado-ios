import Foundation

/// 发现模块用户交互意图
public enum ExploreIntent: ViewIntent, Sendable {
    /// 页面载入
    case onAppear
    /// 切换分类
    case selectCategory(ExploreCategory)
    /// 下拉刷新当前分类
    case refresh
    /// 上拉加载下一页
    case loadNextPage
    /// 选中某本书籍
    case openBook(Book)
}

/// 发现模块单次副作用
public enum ExploreEffect: ViewEffect, Sendable {
    case navigateToDetail(Book)
    case showToast(String)
    case hapticFeedback
}
