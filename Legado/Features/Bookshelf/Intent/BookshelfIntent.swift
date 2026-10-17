import Foundation

/// 书架模块离散交互意图
public enum BookshelfIntent: ViewIntent {
    /// 视图初始化加载
    case onAppear
    /// 下拉刷新书架更新
    case refresh
    /// 切换分组
    case selectGroup(String)
    /// 选中某本书
    case didSelectBook(UUID)
}
