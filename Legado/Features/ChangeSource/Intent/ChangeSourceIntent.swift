import Foundation

/// 换源单向交互意图
public enum ChangeSourceIntent: ViewIntent, Sendable {
    /// 开始并发检索各书源候选
    case startSearch
    /// 用户选择某个候选书源并请求换源
    case selectCandidate(ChangeSourceCandidate)
    /// 取消/关闭换源面板
    case dismiss
}

/// 换源一次性副作用
public enum ChangeSourceEffect: ViewEffect, Sendable {
    case dismiss
    case sourceSwitched(updatedBook: Book, newToc: [Chapter], matchedChapterIndex: Int)
    case showToast(String)
    case hapticFeedback
}
