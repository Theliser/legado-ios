import Foundation

/// 书架书籍项简要视图模型
public struct BookshelfBookItem: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let author: String
    public let latestChapter: String
    public let progressPercent: Double

    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        latestChapter: String,
        progressPercent: Double) {
        self.id = id
        self.title = title
        self.author = author
        self.latestChapter = latestChapter
        self.progressPercent = progressPercent
    }
}

/// 书架模块单一不可变状态
public struct BookshelfState: ViewState {
    public var isLoading: Bool
    public var books: [BookshelfBookItem]
    public var selectedGroup: String

    public init(
        isLoading: Bool = false,
        books: [BookshelfBookItem] = [],
        selectedGroup: String = "全部") {
        self.isLoading = isLoading
        self.books = books
        self.selectedGroup = selectedGroup
    }
}
