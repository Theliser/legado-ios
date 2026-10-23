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
    public let getBookDetailUseCase: GetBookDetailUseCase
    public let getBookTocUseCase: GetBookTocUseCase
    public let checkBookUpdatesUseCase: CheckBookUpdatesUseCase
    public let getChapterContentUseCase: GetChapterContentUseCase
    public let getExploreCategoriesUseCase: GetExploreCategoriesUseCase
    public let exploreBooksUseCase: ExploreBooksUseCase
    public let toggleBookSourceEnabledUseCase: ToggleBookSourceEnabledUseCase
    public let deleteBookSourceUseCase: DeleteBookSourceUseCase
    public let importBookSourcesUseCase: ImportBookSourcesUseCase
    public let debugBookSourceUseCase: DebugBookSourceUseCase
    public let purifyContentUseCase: PurifyContentUseCase
    public let backupToWebDAVUseCase: BackupToWebDAVUseCase
    public let restoreFromWebDAVUseCase: RestoreFromWebDAVUseCase
    public let changeBookSourceUseCase: ChangeBookSourceUseCase
    public let searchBookContentUseCase: SearchBookContentUseCase
    public let bookmarkRepository: BookmarkRepository
    public let getBookmarksUseCase: GetBookmarksUseCase
    public let saveBookmarkUseCase: SaveBookmarkUseCase
    public let deleteBookmarkUseCase: DeleteBookmarkUseCase
    public let bookGroupRepository: BookGroupRepository
    public let getBookGroupsUseCase: GetBookGroupsUseCase
    public let saveBookGroupUseCase: SaveBookGroupUseCase
    public let deleteBookGroupUseCase: DeleteBookGroupUseCase
    public let bookCacheRepository: BookCacheRepository
    public let batchDownloadChaptersUseCase: BatchDownloadChaptersUseCase
    public let manageBookCacheUseCase: ManageBookCacheUseCase
    public let checkBookSourceHealthUseCase: CheckBookSourceHealthUseCase
    public let importLocalBookUseCase: ImportLocalBookUseCase

    public init(inMemory: Bool = false) {
        let provider = ModelContainerProvider(inMemory: inMemory)
        self.modelContainerProvider = provider

        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let bookmarkRepo = BookmarkRepositoryImpl(modelContainer: provider.container)
        let groupRepo = BookGroupRepositoryImpl(modelContainer: provider.container)
        let cacheRepo = BookCacheRepositoryImpl()

        self.bookSourceRepository = sourceRepo
        self.bookRepository = bookRepo
        self.bookmarkRepository = bookmarkRepo
        self.bookGroupRepository = groupRepo
        self.bookCacheRepository = cacheRepo

        self.searchBooksUseCase = SearchBooksUseCase(sourceRepository: sourceRepo)
        self.saveBookToShelfUseCase = SaveBookToShelfUseCase(bookRepository: bookRepo)
        self.getBookshelfUseCase = GetBookshelfUseCase(bookRepository: bookRepo)
        self.removeBookFromShelfUseCase = RemoveBookFromShelfUseCase(bookRepository: bookRepo)
        self.getBookDetailUseCase = GetBookDetailUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo)
        self.getBookTocUseCase = GetBookTocUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo)
        self.checkBookUpdatesUseCase = CheckBookUpdatesUseCase(bookRepository: bookRepo, sourceRepository: sourceRepo)
        self.getChapterContentUseCase = GetChapterContentUseCase(
            sourceRepository: sourceRepo,
            cacheRepository: cacheRepo)
        self.batchDownloadChaptersUseCase = BatchDownloadChaptersUseCase(
            getChapterContentUseCase: self.getChapterContentUseCase,
            bookCacheRepository: cacheRepo)
        self.manageBookCacheUseCase = ManageBookCacheUseCase(bookCacheRepository: cacheRepo)

        self.getExploreCategoriesUseCase = GetExploreCategoriesUseCase(sourceRepository: sourceRepo)
        self.exploreBooksUseCase = ExploreBooksUseCase(sourceRepository: sourceRepo)
        self.toggleBookSourceEnabledUseCase = ToggleBookSourceEnabledUseCase(sourceRepository: sourceRepo)
        self.deleteBookSourceUseCase = DeleteBookSourceUseCase(sourceRepository: sourceRepo)
        self.importBookSourcesUseCase = ImportBookSourcesUseCase(sourceRepository: sourceRepo)
        self.debugBookSourceUseCase = DebugBookSourceUseCase()
        self.purifyContentUseCase = PurifyContentUseCase()
        self.backupToWebDAVUseCase = BackupToWebDAVUseCase(
            bookRepository: bookRepo,
            sourceRepository: sourceRepo)
        self.restoreFromWebDAVUseCase = RestoreFromWebDAVUseCase(
            bookRepository: bookRepo,
            sourceRepository: sourceRepo)
        self.changeBookSourceUseCase = ChangeBookSourceUseCase(
            sourceRepository: sourceRepo,
            bookRepository: bookRepo)
        self.searchBookContentUseCase = SearchBookContentUseCase()
        self.getBookmarksUseCase = GetBookmarksUseCase(bookmarkRepository: bookmarkRepo)
        self.saveBookmarkUseCase = SaveBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        self.deleteBookmarkUseCase = DeleteBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        self.getBookGroupsUseCase = GetBookGroupsUseCase(groupRepository: groupRepo)
        self.saveBookGroupUseCase = SaveBookGroupUseCase(groupRepository: groupRepo)
        self.deleteBookGroupUseCase = DeleteBookGroupUseCase(groupRepository: groupRepo)
        self.checkBookSourceHealthUseCase = CheckBookSourceHealthUseCase()
        self.importLocalBookUseCase = ImportLocalBookUseCase(
            bookRepository: bookRepo,
            bookCacheRepository: cacheRepo)

        if !inMemory {
            primeSampleChapterCache()
            seedInitialDataIfNeeded()
        }
    }

    private func primeSampleChapterCache() {
        let sampleBookUrl = "https://biquge.example.com/book/circle_of_inevitability"
        let sampleContent = """
        　　夜幕降临，微凉的晚风吹拂过荒野，带来了远处不知名野兽的低沉吼声。
        　　卢米安站在高耸的崖壁顶端，俯瞰着下方若隐若现的村落灯火。在这个充满神秘与超凡的世界里，每一个看似宁静的黑夜背后，都潜藏着凡人难以窥见的波诡云谲。
        　　他下意识地摸了摸胸前的银质吊坠，冰冷的金属触感让他狂躁的心绪稍微平复了一些。根据那位神秘女士的指引，只要在特定的星象下完成仪式，就能真正迈入第一序列。
        　　但仪式所需要的祭品并不简单，除了罕见的灵界生物毛发，还需要一份真正直面疯狂与恐惧的勇气。
        　　狂风渐起，天空中厚重的铅云缓缓移动，露出了那一弯猩红如血的残月。命运的齿轮，已在此刻悄然转动。
        　　“时间差不多了。”卢米安低声自语，转身踏上了通往古老遗迹的荒凉小道。
        """

        getChapterContentUseCase.saveChapterCache(
            content: sampleContent,
            bookUrl: sampleBookUrl,
            index: 0)
    }

    private func seedInitialDataIfNeeded() {
        Task {
            await seedSampleSourcesIfNeeded()
            await seedSampleBookshelfIfNeeded()
        }
    }

    /// 创建搜索 ViewModel
    public func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(
            searchBooksUseCase: searchBooksUseCase,
            saveBookToShelfUseCase: saveBookToShelfUseCase,
            getBookshelfUseCase: getBookshelfUseCase)
    }

    /// 创建书籍详情 ViewModel
    public func makeBookDetailViewModel(book: Book) -> BookDetailViewModel {
        BookDetailViewModel(
            book: book,
            getBookDetailUseCase: getBookDetailUseCase,
            getBookTocUseCase: getBookTocUseCase,
            saveBookToShelfUseCase: saveBookToShelfUseCase,
            removeBookFromShelfUseCase: removeBookFromShelfUseCase,
            bookRepository: bookRepository,
            batchDownloadChaptersUseCase: batchDownloadChaptersUseCase,
            manageBookCacheUseCase: manageBookCacheUseCase)
    }

    /// 创建书架 ViewModel
    public func makeBookshelfViewModel() -> BookshelfViewModel {
        BookshelfViewModel(
            getBookshelfUseCase: getBookshelfUseCase,
            removeBookFromShelfUseCase: removeBookFromShelfUseCase,
            checkBookUpdatesUseCase: checkBookUpdatesUseCase,
            saveBookToShelfUseCase: saveBookToShelfUseCase,
            getBookGroupsUseCase: getBookGroupsUseCase,
            saveBookGroupUseCase: saveBookGroupUseCase,
            deleteBookGroupUseCase: deleteBookGroupUseCase,
            importLocalBookUseCase: importLocalBookUseCase)
    }

    /// 创建阅读器 ViewModel
    public func makeReaderViewModel(
        book: Book,
        initialChapterIndex: Int? = nil,
        showHUDInitially: Bool = false) -> ReaderViewModel {
        ReaderViewModel(
            book: book,
            initialChapterIndex: initialChapterIndex,
            showHUDInitially: showHUDInitially,
            getChapterContentUseCase: getChapterContentUseCase,
            getBookTocUseCase: getBookTocUseCase,
            bookRepository: bookRepository,
            getBookmarksUseCase: getBookmarksUseCase,
            saveBookmarkUseCase: saveBookmarkUseCase,
            deleteBookmarkUseCase: deleteBookmarkUseCase)
    }

    /// 创建发现 ViewModel
    public func makeExploreViewModel() -> ExploreViewModel {
        ExploreViewModel(
            getExploreCategoriesUseCase: getExploreCategoriesUseCase,
            exploreBooksUseCase: exploreBooksUseCase)
    }

    /// 创建书源管理 ViewModel
    public func makeSourceManageViewModel() -> SourceManageViewModel {
        SourceManageViewModel(
            sourceRepository: bookSourceRepository,
            toggleEnabledUseCase: toggleBookSourceEnabledUseCase,
            deleteSourceUseCase: deleteBookSourceUseCase,
            importSourcesUseCase: importBookSourcesUseCase,
            debugSourceUseCase: debugBookSourceUseCase,
            checkHealthUseCase: checkBookSourceHealthUseCase)
    }

    /// 创建系统设置 ViewModel
    public func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            backupUseCase: backupToWebDAVUseCase,
            restoreUseCase: restoreFromWebDAVUseCase,
            manageBookCacheUseCase: manageBookCacheUseCase)
    }

    /// 创建换源 ViewModel
    public func makeChangeSourceViewModel(
        book: Book,
        currentChapterTitle: String? = nil,
        currentChapterIndex: Int = 0) -> ChangeSourceViewModel {
        ChangeSourceViewModel(
            book: book,
            currentChapterTitle: currentChapterTitle,
            currentChapterIndex: currentChapterIndex,
            changeBookSourceUseCase: changeBookSourceUseCase)
    }

    /// 创建正文全文搜索 ViewModel
    public func makeBookSearchContentViewModel(
        book: Book,
        chapters: [Chapter]) -> BookSearchContentViewModel {
        BookSearchContentViewModel(
            book: book,
            chapters: chapters,
            getChapterContentUseCase: getChapterContentUseCase,
            searchUseCase: searchBookContentUseCase)
    }
}
