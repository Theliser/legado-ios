import Foundation

/// 添加或保存书籍至书架用例
public final class SaveBookToShelfUseCase: Sendable {
    private let bookRepository: BookRepository

    public init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
    }

    public func execute(_ book: Book) async throws {
        try await bookRepository.saveBook(book)
    }

    /// 从搜索结果转换并加入书架
    public func execute(from searchResult: SearchResult) async throws {
        let book = Book(
            bookUrl: searchResult.bookUrl,
            tocUrl: searchResult.tocUrl,
            origin: searchResult.origin,
            originName: searchResult.originName,
            name: searchResult.name,
            author: searchResult.author,
            kind: searchResult.kind,
            coverUrl: searchResult.coverUrl,
            intro: searchResult.intro,
            latestChapterTitle: searchResult.latestChapterTitle,
            wordCount: searchResult.wordCount)
        try await bookRepository.saveBook(book)
    }
}
