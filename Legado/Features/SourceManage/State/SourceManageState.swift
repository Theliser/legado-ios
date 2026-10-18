import Foundation

/// 书源管理状态模型
public struct SourceManageState: ViewState, Equatable, Sendable {
    /// 所有书源列表
    public var sources: [BookSource]
    /// 搜索过滤词
    public var searchKeyword: String
    /// 是否正在加载
    public var isLoading: Bool
    /// 导入弹窗是否弹出
    public var isImportSheetPresented: Bool
    /// 当前正在调试的书源
    public var debuggingSource: BookSource?
    /// 调试诊断报告
    public var debugReport: SourceDebugReport?
    /// 是否正在调试中
    public var isDebugging: Bool
    /// 调试目标
    public var debugTarget: SourceDebugTarget
    /// 调试输入内容
    public var debugQuery: String
    /// 调试日志过滤器
    public var debugFilter: SourceDebugFilter
    /// 调试快捷预设示例
    public var debugExamples: [SourceDebugExample]
    /// 调试实时日志条目
    public var debugLogs: [SourceDebugLog]
    /// 选中的查看详情数据载荷的日志
    public var selectedPayloadLog: SourceDebugLog?
    /// 错误提示
    public var errorMessage: String?

    public init(
        sources: [BookSource] = [],
        searchKeyword: String = "",
        isLoading: Bool = false,
        isImportSheetPresented: Bool = false,
        debuggingSource: BookSource? = nil,
        debugReport: SourceDebugReport? = nil,
        isDebugging: Bool = false,
        debugTarget: SourceDebugTarget = .search,
        debugQuery: String = "",
        debugFilter: SourceDebugFilter = .all,
        debugExamples: [SourceDebugExample] = [],
        debugLogs: [SourceDebugLog] = [],
        selectedPayloadLog: SourceDebugLog? = nil,
        errorMessage: String? = nil) {
        self.sources = sources
        self.searchKeyword = searchKeyword
        self.isLoading = isLoading
        self.isImportSheetPresented = isImportSheetPresented
        self.debuggingSource = debuggingSource
        self.debugReport = debugReport
        self.isDebugging = isDebugging
        self.debugTarget = debugTarget
        self.debugQuery = debugQuery
        self.debugFilter = debugFilter
        self.debugExamples = debugExamples
        self.debugLogs = debugLogs
        self.selectedPayloadLog = selectedPayloadLog
        self.errorMessage = errorMessage
    }

    /// 依搜索关键词过滤后的书源
    public var filteredSources: [BookSource] {
        guard !searchKeyword.isEmpty else { return sources }
        return sources.filter {
            $0.bookSourceName.localizedCaseInsensitiveContains(searchKeyword) ||
                $0.bookSourceUrl.localizedCaseInsensitiveContains(searchKeyword)
        }
    }

    /// 依分类过滤后的调试日志
    public var filteredDebugLogs: [SourceDebugLog] {
        switch debugFilter {
        case .all:
            return debugLogs

        case .messages:
            return debugLogs.filter { $0.level == .info || $0.level == .success }

        case .payload:
            return debugLogs.filter { $0.level == .payload || $0.payload != nil }

        case .errors:
            return debugLogs.filter { $0.level == .error || $0.level == .warning }
        }
    }
}
