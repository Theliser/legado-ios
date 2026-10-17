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
        errorMessage: String? = nil) {
        self.sources = sources
        self.searchKeyword = searchKeyword
        self.isLoading = isLoading
        self.isImportSheetPresented = isImportSheetPresented
        self.debuggingSource = debuggingSource
        self.debugReport = debugReport
        self.isDebugging = isDebugging
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
}
