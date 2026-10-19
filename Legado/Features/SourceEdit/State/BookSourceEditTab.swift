import Foundation

/// 书源编辑页面规则分段（与 Android 完全对齐，扩充评语规则）
public enum BookSourceEditTab: String, CaseIterable, Identifiable, Sendable {
    case base = "基本"
    case search = "搜索"
    case explore = "发现"
    case info = "详情"
    case toc = "目录"
    case content = "正文"
    case review = "评语"

    public var id: String {
        rawValue
    }

    public var iconName: String {
        switch self {
        case .base:
            return "slider.horizontal.3"

        case .search:
            return "magnifyingglass"

        case .explore:
            return "safari"

        case .info:
            return "doc.text"

        case .toc:
            return "list.bullet"

        case .content:
            return "text.book.closed"

        case .review:
            return "bubble.left.and.bubble.right"
        }
    }
}
