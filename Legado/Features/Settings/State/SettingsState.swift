import Foundation

/// 系统设置状态模型
public struct SettingsState: ViewState, Equatable, Sendable {
    public var webDAVConfig: WebDAVConfig
    public var isTestingConnection: Bool
    public var isBackingUp: Bool
    public var isRestoring: Bool
    public var lastBackupSummary: WebDAVBackupSummary?
    public var speechRate: Float
    public var speechPitch: Float
    public var cacheSizeBytes: Int64
    public var errorMessage: String?
    public var successMessage: String?

    public init(
        webDAVConfig: WebDAVConfig = WebDAVConfig(),
        isTestingConnection: Bool = false,
        isBackingUp: Bool = false,
        isRestoring: Bool = false,
        lastBackupSummary: WebDAVBackupSummary? = nil,
        speechRate: Float = 0.5,
        speechPitch: Float = 1.0,
        cacheSizeBytes: Int64 = 0,
        errorMessage: String? = nil,
        successMessage: String? = nil) {
        self.webDAVConfig = webDAVConfig
        self.isTestingConnection = isTestingConnection
        self.isBackingUp = isBackingUp
        self.isRestoring = isRestoring
        self.lastBackupSummary = lastBackupSummary
        self.speechRate = speechRate
        self.speechPitch = speechPitch
        self.cacheSizeBytes = cacheSizeBytes
        self.errorMessage = errorMessage
        self.successMessage = successMessage
    }

    public var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSizeBytes, countStyle: .file)
    }
}
