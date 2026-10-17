import Foundation

/// 书架模块离散交互意图
public enum BookshelfIntent: ViewIntent, Equatable {
    /// 视图初始化加载
    case onAppear
    /// 下拉刷新检查书籍最新章节更新
    case refresh
    /// 切换分组
    case selectGroup(String)
    /// 选中某本书进行阅读
    case didSelectBook(Book)
    /// 查看书籍详情
    case openBookDetail(Book)
    /// 移除书籍
    case removeBook(bookUrl: String)
}

/// 书架副作用
public enum BookshelfEffect: ViewEffect, Equatable {
    case navigateToReader(Book)
    case navigateToDetail(Book)
    case showToast(String)
    case hapticFeedback
}
