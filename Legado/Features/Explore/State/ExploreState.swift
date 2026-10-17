import Foundation

/// 发现模块展示状态
public struct ExploreState: ViewState, Equatable, Sendable {
    /// 所有可用分类与榜单
    public var categories: [ExploreCategory]
    /// 当前选中的分类
    public var selectedCategory: ExploreCategory?
    /// 当前分类下的书籍列表
    public var books: [Book]
    /// 当前分页页码
    public var currentPage: Int
    /// 是否正在加载分类
    public var isLoadingCategories: Bool
    /// 是否正在加载书籍列表
    public var isLoadingBooks: Bool
    /// 错误提示
    public var errorMessage: String?

    public init(
        categories: [ExploreCategory] = [],
        selectedCategory: ExploreCategory? = nil,
        books: [Book] = [],
        currentPage: Int = 1,
        isLoadingCategories: Bool = false,
        isLoadingBooks: Bool = false,
        errorMessage: String? = nil) {
        self.categories = categories
        self.selectedCategory = selectedCategory
        self.books = books
        self.currentPage = currentPage
        self.isLoadingCategories = isLoadingCategories
        self.isLoadingBooks = isLoadingBooks
        self.errorMessage = errorMessage
    }
}
