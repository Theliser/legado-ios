import Foundation

/// 书架模块单一不可变状态
public struct BookshelfState: ViewState, Equatable {
    public var isLoading: Bool
    public var books: [Book]
    public var selectedGroup: String
    public var groups: [String]

    public init(
        isLoading: Bool = false,
        books: [Book] = [],
        selectedGroup: String = "全部",
        groups: [String] = ["全部", "在读", "未读", "完结"]) {
        self.isLoading = isLoading
        self.books = books
        self.selectedGroup = selectedGroup
        self.groups = groups
    }
}
