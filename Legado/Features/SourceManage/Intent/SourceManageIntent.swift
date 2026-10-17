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
    case runDebug(source: BookSource, keyword: String)
}

/// 书源管理单次副作用
public enum SourceManageEffect: ViewEffect, Sendable {
    case showToast(String)
    case hapticFeedback
}
