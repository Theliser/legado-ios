import Foundation

/// 正文搜索单向状态
public struct BookSearchContentState: ViewState, Sendable {
    public var query: String
    public var matches: [BookSearchMatch]
    public var isSearching: Bool
    public var totalMatchesCount: Int {
        matches.count
    }

    public init(
        query: String = "",
        matches: [BookSearchMatch] = [],
        isSearching: Bool = false) {
        self.query = query
        self.matches = matches
        self.isSearching = isSearching
    }
}
