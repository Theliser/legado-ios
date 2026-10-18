import Foundation

/// 书架布局模式 (宫格封面 vs 详尽列表)
public enum BookshelfLayoutMode: String, CaseIterable, Codable, Sendable {
    case grid = "宫格"
    case list = "列表"
}

/// 书架模块单一不可变状态
public struct BookshelfState: ViewState, Equatable {
    public var isLoading: Bool
    public var books: [Book]
    public var selectedGroup: String
    public var groups: [String]
    public var customGroups: [BookGroup]
    public var layoutMode: BookshelfLayoutMode
    public var isBatchMode: Bool
    public var selectedBookUrls: Set<String>
    public var isRefreshingUpdates: Bool
    public var updatedBookUrls: Set<String>
    public var searchText: String

    public init(
        isLoading: Bool = false,
        books: [Book] = [],
        selectedGroup: String = "全部",
        groups: [String] = ["全部", "在读", "未读", "完结"],
        customGroups: [BookGroup] = [],
        layoutMode: BookshelfLayoutMode = .grid,
        isBatchMode: Bool = false,
        selectedBookUrls: Set<String> = [],
        isRefreshingUpdates: Bool = false,
        updatedBookUrls: Set<String> = [],
        searchText: String = "") {
        self.isLoading = isLoading
        self.books = books
        self.selectedGroup = selectedGroup
        self.groups = groups
        self.customGroups = customGroups
        self.layoutMode = layoutMode
        self.isBatchMode = isBatchMode
        self.selectedBookUrls = selectedBookUrls
        self.isRefreshingUpdates = isRefreshingUpdates
        self.updatedBookUrls = updatedBookUrls
        self.searchText = searchText
    }

    /// 根据当前分组和搜索关键词过滤后的书籍列表
    public var filteredBooks: [Book] {
        var list = books

        if selectedGroup == "在读" {
            list = list.filter { $0.durChapterIndex > 0 }
        } else if selectedGroup == "未读" {
            list = list.filter { $0.durChapterIndex == 0 }
        } else if selectedGroup == "完结" {
            list = list.filter { $0.kind?.contains("完结") == true }
        } else if selectedGroup != "全部" {
            list = list.filter { $0.groupName == selectedGroup }
        }

        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        return list
    }
}
