import Foundation

/// 书籍详情页面状态
public struct BookDetailState: ViewState, Equatable, Sendable {
    /// 书籍领域对象
    public var book: Book
    /// 是否正在加载详情或目录
    public var isLoading: Bool
    /// 是否已在书架中
    public var isInBookshelf: Bool
    /// 章节目录列表
    public var chapters: [Chapter]
    /// 目录抽屉是否弹出
    public var isTocPresented: Bool
    /// 换源弹窗是否弹出
    public var isSourceSwitchPresented: Bool
    /// 目录是否倒序排列
    public var isReverseToc: Bool
    /// 目录搜索过滤关键字
    public var tocSearchText: String
    /// 错误提示
    public var errorMessage: String?

    public init(
        book: Book,
        isLoading: Bool = false,
        isInBookshelf: Bool = false,
        chapters: [Chapter] = [],
        isTocPresented: Bool = false,
        isSourceSwitchPresented: Bool = false,
        isReverseToc: Bool = false,
        tocSearchText: String = "",
        errorMessage: String? = nil) {
        self.book = book
        self.isLoading = isLoading
        self.isInBookshelf = isInBookshelf
        self.chapters = chapters
        self.isTocPresented = isTocPresented
        self.isSourceSwitchPresented = isSourceSwitchPresented
        self.isReverseToc = isReverseToc
        self.tocSearchText = tocSearchText
        self.errorMessage = errorMessage
    }
}
