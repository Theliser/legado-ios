import Foundation

/// 正文搜索用户离散交互意图
public enum BookSearchContentIntent: ViewIntent, Sendable {
    case updateQuery(String)
    case search
    case selectMatch(BookSearchMatch)
    case clear
}

/// 正文搜索一次性副作用
public enum BookSearchContentEffect: ViewEffect, Sendable {
    case dismiss
    case jumpToChapter(chapterIndex: Int, matchOffset: Int)
    case hapticFeedback
}
