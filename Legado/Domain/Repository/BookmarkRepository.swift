import Foundation

/// 书签数据持久化仓储协议
public protocol BookmarkRepository: Sendable {
    /// 获取指定书籍的所有书签
    func getBookmarks(bookName: String, bookAuthor: String) async throws -> [Bookmark]

    /// 保存或更新书签
    func saveBookmark(_ bookmark: Bookmark) async throws

    /// 删除指定书签
    func deleteBookmark(id: String) async throws

    /// 批量删除指定书签
    func deleteBookmarks(ids: [String]) async throws
}
