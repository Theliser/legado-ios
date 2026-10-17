import Foundation

/// 获取书籍目录章节列表用例
public final class GetBookTocUseCase: Sendable {
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

    public func execute(book: Book, forceRefresh: Bool = false) async throws -> [Chapter] {
        // 先查本地缓存
        let cached = try await bookRepository.getChapters(for: book.bookUrl)
        if !cached.isEmpty, !forceRefresh {
            return cached
        }

        let sources = try await sourceRepository.fetchSources()
        guard let source = sources.first(where: { $0.bookSourceUrl == book.origin }) else {
            return cached
        }

        let chapters = try await service.fetchBookToc(book: book, source: source)
        if !chapters.isEmpty {
            try await bookRepository.saveChapters(chapters, for: book.bookUrl)

            // 更新书籍总章节数
            if var currentBook = try await bookRepository.getBook(by: book.bookUrl) {
                currentBook.totalChapterNum = chapters.count
                if let last = chapters.last {
                    currentBook.latestChapterTitle = last.title
                    currentBook.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
                }
                try await bookRepository.saveBook(currentBook)
            }
        }

        return chapters
    }
}
