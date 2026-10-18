import Foundation

/// 书源健康状态与网络连通性报告
public struct SourceHealthReport: Identifiable, Equatable, Sendable {
    public var id: String {
        sourceUrl
    }

    public let sourceUrl: String
    public let sourceName: String
    public let isHealthy: Bool
    public let responseTimeMs: Int
    public let statusCode: Int?
    public let errorMessage: String?

    public init(
        sourceUrl: String,
        sourceName: String,
        isHealthy: Bool,
        responseTimeMs: Int,
        statusCode: Int? = nil,
        errorMessage: String? = nil) {
        self.sourceUrl = sourceUrl
        self.sourceName = sourceName
        self.isHealthy = isHealthy
        self.responseTimeMs = responseTimeMs
        self.statusCode = statusCode
        self.errorMessage = errorMessage
    }
}
