import Foundation

/// 系统设置用户意图
public enum SettingsIntent: ViewIntent {
    case updateWebDAVServer(String)
    case updateWebDAVUsername(String)
    case updateWebDAVPassword(String)
    case updateWebDAVDirectory(String)
    case testWebDAVConnection
    case backupToWebDAV
    case restoreFromWebDAV
    case updateSpeechRate(Float)
    case updateSpeechPitch(Float)
    case refreshCacheSize
    case clearAllCache
    case clearNotice
}

/// 设置副作用事件
public enum SettingsEffect: ViewEffect {
    case showToast(String)
    case hapticFeedback
}
