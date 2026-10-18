import Foundation

/// 书架模块离散交互意图
public enum BookshelfIntent: ViewIntent, Equatable {
    /// 视图初始化加载
    case onAppear
    /// 下拉刷新检查书籍最新章节更新
    case refresh
    /// 搜索过滤词更新
    case updateSearchText(String)
    /// 切换分组
    case selectGroup(String)
    /// 切换布局模式 (宫格 / 列表)
    case toggleLayoutMode
    /// 选中某本书进行阅读
    case didSelectBook(Book)
    /// 查看书籍详情
    case openBookDetail(Book)
    /// 移除书籍
    case removeBook(bookUrl: String)
    /// 创建自定义分组
    case addCustomGroup(name: String)
    /// 删除自定义分组
    case deleteCustomGroup(id: String)
    /// 移动单本书至分组
    case moveBookToGroup(bookUrl: String, groupName: String?)
    /// 切换批量编辑模式
    case toggleBatchMode
    /// 批量模式下选中/取消单选
    case toggleSelectBook(bookUrl: String)
    /// 批量全选
    case selectAll
    /// 批量取消全选
    case deselectAll
    /// 批量移出书架
    case batchRemoveSelected
    /// 批量移动分组
    case batchMoveSelectedToGroup(groupName: String?)
    /// 手动全书架检查更新
    case refreshAllBookUpdates
}

/// 书架副作用
public enum BookshelfEffect: ViewEffect, Equatable {
    case navigateToReader(Book)
    case navigateToDetail(Book)
    case showToast(String)
    case hapticFeedback
}
