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
}

/// 书籍详情一次性副作用
public enum BookDetailEffect: ViewEffect, Equatable, Sendable {
    case showToast(String)
    case navigateToReader(chapterIndex: Int)
    case hapticFeedback
}
