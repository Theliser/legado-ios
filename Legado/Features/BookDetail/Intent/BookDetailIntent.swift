import Foundation

/// 书籍详情用户交互意图
public enum BookDetailIntent: ViewIntent, Equatable, Sendable {
    /// 加载/刷新书籍详情与目录
    case loadDetail
    /// 加入或移出书架
    case toggleBookshelf
    /// 打开目录抽屉
    case openToc
    /// 关闭目录抽屉
    case closeToc
    /// 切换目录正倒序
    case toggleTocReverse
    /// 过滤目录关键词
    case updateTocSearch(String)
    /// 点击某个目录章节直接阅读
    case selectChapter(Chapter)
    /// 打开换源弹窗
    case openSourceSwitch
    /// 选择新书源切换
    case switchSource(SearchResult)
    /// 打开或关闭离线缓存抽屉
    case toggleCacheSheet(Bool)
    /// 刷新离线缓存占用状态
    case refreshCacheInfo
    /// 启动批量离线章节下载
    case startBatchDownload(BatchDownloadOption)
    /// 取消批量下载
    case cancelBatchDownload
    /// 清空本书离线缓存
    case clearBookCache
    /// 更新书籍实体与新目录
    case updateBook(Book, [Chapter])
}

/// 书籍详情一次性副作用
public enum BookDetailEffect: ViewEffect, Equatable, Sendable {
    case showToast(String)
    case navigateToReader(chapterIndex: Int)
    case hapticFeedback
}
