import Foundation

/// 从书架移除书籍用例
public final class RemoveBookFromShelfUseCase: Sendable {
    private let bookRepository: BookRepository

    public init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
    }

    public func execute(bookUrl: String) async throws {
        try await bookRepository.removeBook(by: bookUrl)
    }
}
