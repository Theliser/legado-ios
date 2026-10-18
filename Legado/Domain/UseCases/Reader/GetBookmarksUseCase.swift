import Foundation

/// 获取书籍书签用例
public final class GetBookmarksUseCase: Sendable {
    private let bookmarkRepository: BookmarkRepository

    public init(bookmarkRepository: BookmarkRepository) {
        self.bookmarkRepository = bookmarkRepository
    }

    public func execute(bookName: String, bookAuthor: String) async throws -> [Bookmark] {
        try await bookmarkRepository.getBookmarks(bookName: bookName, bookAuthor: bookAuthor)
    }
}
