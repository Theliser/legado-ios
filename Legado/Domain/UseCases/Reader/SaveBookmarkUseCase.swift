import Foundation

/// 保存或更新书签用例
public final class SaveBookmarkUseCase: Sendable {
    private let bookmarkRepository: BookmarkRepository

    public init(bookmarkRepository: BookmarkRepository) {
        self.bookmarkRepository = bookmarkRepository
    }

    public func execute(bookmark: Bookmark) async throws {
        try await bookmarkRepository.saveBookmark(bookmark)
    }
}
