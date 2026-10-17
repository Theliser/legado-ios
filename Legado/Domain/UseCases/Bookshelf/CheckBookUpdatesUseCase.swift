import Foundation

/// 检查书架书籍更新用例
public final class CheckBookUpdatesUseCase: Sendable {
    private let bookRepository: BookRepository
    private let sourceRepository: BookSourceRepository
    private let service: SourceDetailAndTocService

    public init(
        bookRepository: BookRepository,
        sourceRepository: BookSourceRepository,
        service: SourceDetailAndTocService = .shared) {
        self.bookRepository = bookRepository
        self.sourceRepository = sourceRepository
        self.service = service
    }

    /// 检查所有书架书籍更新，返回发生章节更新的书籍数量
    public func execute() async throws -> Int {
        let books = try await bookRepository.getBookshelf()
        let sources = try await sourceRepository.fetchEnabledSources()
        let sourceMap = Dictionary(uniqueKeysWithValues: sources.map { ($0.bookSourceUrl, $0) })

        var updatedCount = 0

        for book in books {
            guard let source = sourceMap[book.origin] else { continue }

            do {
                let latestBook = try await service.fetchBookDetail(book: book, source: source)
                if let newTitle = latestBook.latestChapterTitle,
                   !newTitle.isEmpty,
                   newTitle != book.latestChapterTitle {
                    var modified = book
                    modified.latestChapterTitle = newTitle
                    modified.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
                    try await bookRepository.saveBook(modified)
                    updatedCount += 1
                }
            } catch {
                continue
            }
        }

        return updatedCount
    }
}
