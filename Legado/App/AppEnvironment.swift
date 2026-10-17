import Foundation
import SwiftData

/// 全局依赖注入环境容器
@MainActor
public final class AppEnvironment: ObservableObject {
    public static let shared = AppEnvironment()

    public let modelContainerProvider: ModelContainerProvider
    public let bookSourceRepository: BookSourceRepository
    public let bookRepository: BookRepository

    // UseCases
    public let searchBooksUseCase: SearchBooksUseCase
    public let saveBookToShelfUseCase: SaveBookToShelfUseCase
    public let getBookshelfUseCase: GetBookshelfUseCase
    public let removeBookFromShelfUseCase: RemoveBookFromShelfUseCase

    public init(inMemory: Bool = false) {
        let provider = ModelContainerProvider(inMemory: inMemory)
        self.modelContainerProvider = provider

        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)

        self.bookSourceRepository = sourceRepo
        self.bookRepository = bookRepo

        self.searchBooksUseCase = SearchBooksUseCase(sourceRepository: sourceRepo)
        self.saveBookToShelfUseCase = SaveBookToShelfUseCase(bookRepository: bookRepo)
        self.getBookshelfUseCase = GetBookshelfUseCase(bookRepository: bookRepo)
        self.removeBookFromShelfUseCase = RemoveBookFromShelfUseCase(bookRepository: bookRepo)
    }

    /// 创建搜索 ViewModel
    public func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(
            searchBooksUseCase: searchBooksUseCase,
            saveBookToShelfUseCase: saveBookToShelfUseCase,
            getBookshelfUseCase: getBookshelfUseCase)
    }
}
