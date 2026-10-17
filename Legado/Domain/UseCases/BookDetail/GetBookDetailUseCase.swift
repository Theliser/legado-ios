import Foundation

/// 获取书籍详细信息用例
public final class GetBookDetailUseCase: Sendable {
    private let sourceRepository: BookSourceRepository
    private let bookRepository: BookRepository
    private let service: SourceDetailAndTocService

    public init(
        sourceRepository: BookSourceRepository,
        bookRepository: BookRepository,
        service: SourceDetailAndTocService = .shared) {
        self.sourceRepository = sourceRepository
        self.bookRepository = bookRepository
        self.service = service
    }

    public func execute(book: Book) async throws -> Book {
        let sources = try await sourceRepository.fetchSources()
        guard let source = sources.first(where: { $0.bookSourceUrl == book.origin }) else {
            return book
        }

        let updatedBook = try await service.fetchBookDetail(book: book, source: source)

        // 若已经在书架中，则同步刷新书架存储
        if let existing = try await bookRepository.getBook(by: book.bookUrl) {
            var merged = updatedBook
            merged.durChapterIndex = existing.durChapterIndex
            merged.durChapterPos = existing.durChapterPos
            merged.durChapterTitle = existing.durChapterTitle
            merged.durChapterTime = existing.durChapterTime
            merged.order = existing.order
            try await bookRepository.saveBook(merged)
        }

        return updatedBook
    }
}
