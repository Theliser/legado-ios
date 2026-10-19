import Foundation

/// 书源管理用户交互意图
public enum SourceManageIntent: ViewIntent, Sendable {
    case loadSources
    case updateSearchKeyword(String)
    case toggleSourceEnabled(sourceUrl: String, enabled: Bool)
    case deleteSource(sourceUrl: String)
    case openImportSheet
    case closeImportSheet
    case importFromText(String)
    case openDebug(BookSource)
    case closeDebug
    case selectDebugTarget(SourceDebugTarget)
    case updateDebugQuery(String)
    case selectDebugFilter(SourceDebugFilter)
    case useDebugExample(SourceDebugExample)
    case startDebug
    case stopDebug
    case clearDebugLogs
    case selectPayloadLog(SourceDebugLog?)
    case runDebug(source: BookSource, keyword: String)
    case openEdit(BookSource)
    case closeEdit
    case openNewSource
    case closeNewSource
    case selectGroup(String)
    case startHealthCheck
    case stopHealthCheck
    case disableInvalidSources
    case deleteInvalidSources
}

/// 书源管理单次副作用
public enum SourceManageEffect: ViewEffect, Sendable {
    case showToast(String)
    case hapticFeedback
}
