import Foundation

/// 获取书架书籍用例
public final class GetBookshelfUseCase: Sendable {
    private let bookRepository: BookRepository

    public init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
    }

    public func execute() async throws -> [Book] {
        try await bookRepository.getBookshelf()
    }
}
