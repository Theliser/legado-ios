import Foundation

/// 书源管理状态模型
public struct SourceManageState: ViewState, Equatable, Sendable {
    /// 所有书源列表
    public var sources: [BookSource]
    /// 搜索过滤词
    public var searchKeyword: String
    /// 当前选中的书源分组 (默认 "全部")
    public var selectedGroup: String
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
    /// 书源连通性体检报告 (Key: sourceUrl)
    public var healthReports: [String: SourceHealthReport]
    /// 是否正在批量体检中
    public var isCheckingHealth: Bool
    /// 体检进度 (已完成, 总数)
    public var healthCheckProgress: (completed: Int, total: Int)?
    /// 错误提示
    public var errorMessage: String?

    public init(
        sources: [BookSource] = [],
        searchKeyword: String = "",
        selectedGroup: String = "全部",
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
        healthReports: [String: SourceHealthReport] = [:],
        isCheckingHealth: Bool = false,
        healthCheckProgress: (completed: Int, total: Int)? = nil,
        errorMessage: String? = nil) {
        self.sources = sources
        self.searchKeyword = searchKeyword
        self.selectedGroup = selectedGroup
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
        self.healthReports = healthReports
        self.isCheckingHealth = isCheckingHealth
        self.healthCheckProgress = healthCheckProgress
        self.errorMessage = errorMessage
    }

    /// 所有可用分组标签集合 (系统默认 + 书源元数据自定义分组)
    public var availableGroups: [String] {
        var groupSet = Set<String>()
        for source in sources {
            if let group = source.bookSourceGroup, !group.isEmpty {
                let parts = group.components(separatedBy: CharacterSet(charactersIn: ",;，；"))
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        groupSet.insert(trimmed)
                    }
                }
            }
            if source.bookSourceType == 1 {
                groupSet.insert("有声")
            } else if source.bookSourceType == 2 {
                groupSet.insert("漫画")
            }
        }
        var sorted = groupSet.sorted()
        sorted.insert("全部", at: 0)
        return sorted
    }

    /// 依分组和关键词过滤后的书源
    public var filteredSources: [BookSource] {
        var result = sources

        // 分组过滤
        if selectedGroup != "全部" {
            result = result.filter { source in
                if selectedGroup == "有声", source.bookSourceType == 1 {
                    return true
                }
                if selectedGroup == "漫画", source.bookSourceType == 2 {
                    return true
                }
                if let group = source.bookSourceGroup {
                    return group.contains(selectedGroup)
                }
                return false
            }
        }

        // 关键词过滤
        guard !searchKeyword.isEmpty else { return result }
        return result.filter {
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

    public static func == (lhs: SourceManageState, rhs: SourceManageState) -> Bool {
        lhs.sources == rhs.sources &&
            lhs.searchKeyword == rhs.searchKeyword &&
            lhs.selectedGroup == rhs.selectedGroup &&
            lhs.isLoading == rhs.isLoading &&
            lhs.isImportSheetPresented == rhs.isImportSheetPresented &&
            lhs.debuggingSource == rhs.debuggingSource &&
            lhs.debugReport == rhs.debugReport &&
            lhs.isDebugging == rhs.isDebugging &&
            lhs.debugTarget == rhs.debugTarget &&
            lhs.debugQuery == rhs.debugQuery &&
            lhs.debugFilter == rhs.debugFilter &&
            lhs.debugExamples == rhs.debugExamples &&
            lhs.debugLogs == rhs.debugLogs &&
            lhs.selectedPayloadLog == rhs.selectedPayloadLog &&
            lhs.healthReports == rhs.healthReports &&
            lhs.isCheckingHealth == rhs.isCheckingHealth &&
            lhs.healthCheckProgress?.completed == rhs.healthCheckProgress?.completed &&
            lhs.healthCheckProgress?.total == rhs.healthCheckProgress?.total &&
            lhs.errorMessage == rhs.errorMessage
    }
}
