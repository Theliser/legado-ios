import Foundation

/// 调试目标类型（与 Legado Android 对齐）
public enum SourceDebugTarget: String, CaseIterable, Identifiable, Equatable, Sendable {
    case search = "搜索"
    case explore = "发现"
    case info = "详情"
    case toc = "目录"
    case content = "正文"

    public var id: String {
        rawValue
    }

    public var iconName: String {
        switch self {
        case .search: return "magnifyingglass"
        case .explore: return "safari"
        case .info: return "book.closed"
        case .toc: return "list.bullet"
        case .content: return "doc.text"
        }
    }

    public var placeholder: String {
        switch self {
        case .search: return "输入搜索关键字（如：斗罗大陆）"
        case .explore: return "输入发现分类 URL 或名称"
        case .info: return "输入书籍详情页完整 URL"
        case .toc: return "输入目录页完整 URL"
        case .content: return "输入正文章节完整 URL"
        }
    }
}

/// 调试日志过滤分类
public enum SourceDebugFilter: String, CaseIterable, Identifiable, Equatable, Sendable {
    case all = "全部"
    case messages = "流程"
    case payload = "数据"
    case errors = "错误"

    public var id: String {
        rawValue
    }
}

/// 快速调试预设示例
public struct SourceDebugExample: Identifiable, Equatable, Sendable {
    public var id: String {
        "\(target.rawValue):\(value)"
    }

    public let title: String
    public let target: SourceDebugTarget
    public let value: String

    public init(title: String, target: SourceDebugTarget, value: String) {
        self.title = title
        self.target = target
        self.value = value
    }
}

/// 书源调试日志项
public struct SourceDebugLog: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let elapsedMs: Int
    public let level: LogLevel
    public let message: String
    public let payload: String?

    public enum LogLevel: String, Equatable, Sendable {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARN"
        case error = "ERROR"
        case payload = "DATA"
    }

    public var timeFormatted: String {
        let totalSeconds = elapsedMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let millis = elapsedMs % 1000
        return String(format: "[%02d:%02d.%03d]", minutes, seconds, millis)
    }

    public init(
        level: LogLevel = .info,
        message: String,
        elapsedMs: Int = 0,
        payload: String? = nil) {
        self.timestamp = Date()
        self.elapsedMs = elapsedMs
        self.level = level
        self.message = message
        self.payload = payload
    }
}

/// 书源调试诊断报告
public struct SourceDebugReport: Equatable, Sendable {
    public let sourceName: String
    public let isSuccess: Bool
    public let durationMs: Int
    public let logs: [SourceDebugLog]
    public let sampleResult: SearchResult?

    public init(
        sourceName: String,
        isSuccess: Bool,
        durationMs: Int,
        logs: [SourceDebugLog],
        sampleResult: SearchResult? = nil) {
        self.sourceName = sourceName
        self.isSuccess = isSuccess
        self.durationMs = durationMs
        self.logs = logs
        self.sampleResult = sampleResult
    }
}
