import Foundation

/// 书源调试日志项
public struct SourceDebugLog: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let message: String

    public enum LogLevel: String, Equatable, Sendable {
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARN"
        case error = "ERROR"
    }

    public init(level: LogLevel = .info, message: String) {
        self.timestamp = Date()
        self.level = level
        self.message = message
    }
}

/// 书源实时调试报告
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
