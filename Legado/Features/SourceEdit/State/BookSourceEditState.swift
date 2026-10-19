import Foundation

/// 书源编辑页面唯一状态（MVI State）
public struct BookSourceEditState: ViewState, Equatable, Sendable {
    /// 当前正在编辑的书源草稿
    public var source: BookSource
    /// 载入时的原始书源对象（用于脏检查与主键变更追踪）
    public var originalSource: BookSource?
    /// 当前选中的规则标签页
    public var selectedTab: BookSourceEditTab
    /// 是否处于 JSON 源码编辑模式
    public var isJsonEditorPresented: Bool
    /// JSON 源码文本缓存
    public var rawJsonText: String
    /// 是否存在未保存的修改
    public var isDirty: Bool
    /// 是否正在加载或初始化
    public var isLoading: Bool
    /// 是否正在保存
    public var isSaving: Bool
    /// 错误信息提示
    public var errorMessage: String?
    /// 当前获得焦点的字段标识（用于语法标记胶囊插入）
    public var activeFieldKey: String?
    /// 是否弹出放弃修改二次确认弹窗
    public var isDiscardAlertPresented: Bool
    /// 是否正在展示调试控制台
    public var isDebuggingPresented: Bool

    public init(
        source: BookSource = BookSource(bookSourceUrl: "", bookSourceName: ""),
        originalSource: BookSource? = nil,
        selectedTab: BookSourceEditTab = .base,
        isJsonEditorPresented: Bool = false,
        rawJsonText: String = "",
        isDirty: Bool = false,
        isLoading: Bool = false,
        isSaving: Bool = false,
        errorMessage: String? = nil,
        activeFieldKey: String? = nil,
        isDiscardAlertPresented: Bool = false,
        isDebuggingPresented: Bool = false) {
        self.source = source
        self.originalSource = originalSource
        self.selectedTab = selectedTab
        self.isJsonEditorPresented = isJsonEditorPresented
        self.rawJsonText = rawJsonText
        self.isDirty = isDirty
        self.isLoading = isLoading
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.activeFieldKey = activeFieldKey
        self.isDiscardAlertPresented = isDiscardAlertPresented
        self.isDebuggingPresented = isDebuggingPresented
    }

    /// 是否为新建书源
    public var isNewSource: Bool {
        originalSource == nil
    }

    /// 表单校验提示
    public var validationError: String? {
        if source.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "书源名称不能为空"
        }
        if source.bookSourceUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "书源 URL 不能为空"
        }
        return nil
    }

    /// 是否允许保存
    public var canSave: Bool {
        validationError == nil && !isSaving
    }

    /// 根据字段键名获取对应字段的字符串值
    public func fieldValue(for key: String) -> String {
        if key.hasPrefix("ruleSearch.") || key == "searchUrl" {
            return searchFieldValue(for: key)
        }
        if key.hasPrefix("ruleExplore.") || key == "exploreUrl" {
            return exploreFieldValue(for: key)
        }
        if key.hasPrefix("ruleBookInfo.") {
            return infoFieldValue(for: key)
        }
        if key.hasPrefix("ruleToc.") {
            return tocFieldValue(for: key)
        }
        if key.hasPrefix("ruleContent.") {
            return contentFieldValue(for: key)
        }
        if key.hasPrefix("ruleReview.") {
            return reviewFieldValue(for: key)
        }
        return baseFieldValue(for: key)
    }

    private func baseFieldValue(for key: String) -> String {
        switch key {
        case "bookSourceName": return source.bookSourceName
        case "bookSourceUrl": return source.bookSourceUrl
        case "bookSourceGroup": return source.bookSourceGroup ?? ""
        case "bookSourceComment": return source.bookSourceComment ?? ""
        case "loginUrl": return source.loginUrl ?? ""
        case "header": return source.header ?? ""
        case "bookUrlPattern": return source.bookUrlPattern ?? ""
        default: return ""
        }
    }

    private func searchFieldValue(for key: String) -> String {
        switch key {
        case "searchUrl": return source.searchUrl ?? ""
        case "ruleSearch.checkKeyWord": return source.ruleSearch?.checkKeyWord ?? ""
        case "ruleSearch.bookList": return source.ruleSearch?.bookList ?? ""
        case "ruleSearch.name": return source.ruleSearch?.name ?? ""
        case "ruleSearch.author": return source.ruleSearch?.author ?? ""
        case "ruleSearch.kind": return source.ruleSearch?.kind ?? ""
        default: return searchSecondaryFieldValue(for: key)
        }
    }

    private func searchSecondaryFieldValue(for key: String) -> String {
        switch key {
        case "ruleSearch.wordCount": return source.ruleSearch?.wordCount ?? ""
        case "ruleSearch.lastChapter": return source.ruleSearch?.lastChapter ?? ""
        case "ruleSearch.intro": return source.ruleSearch?.intro ?? ""
        case "ruleSearch.coverUrl": return source.ruleSearch?.coverUrl ?? ""
        case "ruleSearch.bookUrl": return source.ruleSearch?.bookUrl ?? ""
        default: return ""
        }
    }

    private func exploreFieldValue(for key: String) -> String {
        switch key {
        case "exploreUrl": return source.exploreUrl ?? ""
        case "ruleExplore.bookList": return source.ruleExplore?.bookList ?? ""
        case "ruleExplore.name": return source.ruleExplore?.name ?? ""
        case "ruleExplore.author": return source.ruleExplore?.author ?? ""
        case "ruleExplore.kind": return source.ruleExplore?.kind ?? ""
        default: return exploreSecondaryFieldValue(for: key)
        }
    }

    private func exploreSecondaryFieldValue(for key: String) -> String {
        switch key {
        case "ruleExplore.wordCount": return source.ruleExplore?.wordCount ?? ""
        case "ruleExplore.lastChapter": return source.ruleExplore?.lastChapter ?? ""
        case "ruleExplore.intro": return source.ruleExplore?.intro ?? ""
        case "ruleExplore.coverUrl": return source.ruleExplore?.coverUrl ?? ""
        case "ruleExplore.bookUrl": return source.ruleExplore?.bookUrl ?? ""
        default: return ""
        }
    }

    private func infoFieldValue(for key: String) -> String {
        switch key {
        case "ruleBookInfo.init": return source.ruleBookInfo?.bookInfoInit ?? ""
        case "ruleBookInfo.name": return source.ruleBookInfo?.name ?? ""
        case "ruleBookInfo.author": return source.ruleBookInfo?.author ?? ""
        case "ruleBookInfo.kind": return source.ruleBookInfo?.kind ?? ""
        case "ruleBookInfo.wordCount": return source.ruleBookInfo?.wordCount ?? ""
        default: return infoSecondaryFieldValue(for: key)
        }
    }

    private func infoSecondaryFieldValue(for key: String) -> String {
        switch key {
        case "ruleBookInfo.lastChapter": return source.ruleBookInfo?.lastChapter ?? ""
        case "ruleBookInfo.intro": return source.ruleBookInfo?.intro ?? ""
        case "ruleBookInfo.coverUrl": return source.ruleBookInfo?.coverUrl ?? ""
        case "ruleBookInfo.tocUrl": return source.ruleBookInfo?.tocUrl ?? ""
        case "ruleBookInfo.canReName": return source.ruleBookInfo?.canReName ?? ""
        default: return ""
        }
    }

    private func tocFieldValue(for key: String) -> String {
        switch key {
        case "ruleToc.chapterList": return source.ruleToc?.chapterList ?? ""
        case "ruleToc.chapterName": return source.ruleToc?.chapterName ?? ""
        case "ruleToc.chapterUrl": return source.ruleToc?.chapterUrl ?? ""
        case "ruleToc.isVip": return source.ruleToc?.isVip ?? ""
        case "ruleToc.updateTime": return source.ruleToc?.updateTime ?? ""
        case "ruleToc.nextTocUrl": return source.ruleToc?.nextTocUrl ?? ""
        default: return ""
        }
    }

    private func contentFieldValue(for key: String) -> String {
        switch key {
        case "ruleContent.content": return source.ruleContent?.content ?? ""
        case "ruleContent.nextContentUrl": return source.ruleContent?.nextContentUrl ?? ""
        case "ruleContent.sourceRegex": return source.ruleContent?.sourceRegex ?? ""
        case "ruleContent.webJs": return source.ruleContent?.webJs ?? ""
        default: return ""
        }
    }

    private func reviewFieldValue(for key: String) -> String {
        switch key {
        case "ruleReview.reviewUrl": return source.ruleReview?.reviewUrl ?? ""
        case "ruleReview.contentRule": return source.ruleReview?.contentRule ?? ""
        case "ruleReview.avatarRule": return source.ruleReview?.avatarRule ?? ""
        case "ruleReview.postTimeRule": return source.ruleReview?.postTimeRule ?? ""
        default: return ""
        }
    }
}
