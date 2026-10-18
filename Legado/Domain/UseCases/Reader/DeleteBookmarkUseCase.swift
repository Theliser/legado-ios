import Foundation

/// 删除书签用例
public final class DeleteBookmarkUseCase: Sendable {
    private let bookmarkRepository: BookmarkRepository

    public init(bookmarkRepository: BookmarkRepository) {
        self.bookmarkRepository = bookmarkRepository
    }

    public func execute(id: String) async throws {
        try await bookmarkRepository.deleteBookmark(id: id)
    }
}
