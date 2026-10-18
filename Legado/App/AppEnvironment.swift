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
        self.getBookDetailUseCase = GetBookDetailUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo)
        self.getBookTocUseCase = GetBookTocUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo)
        self.checkBookUpdatesUseCase = CheckBookUpdatesUseCase(bookRepository: bookRepo, sourceRepository: sourceRepo)
        self.getChapterContentUseCase = GetChapterContentUseCase(sourceRepository: sourceRepo)

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

    private func seedSampleSourcesIfNeeded() async {
        let sources = (try? await bookSourceRepository.fetchSources()) ?? []
        var toSave: [BookSource] = []

        let sampleSource = buildDefaultSampleSource()
        if !sources.contains(where: { $0.bookSourceUrl == sampleSource.bookSourceUrl }) {
            toSave.append(sampleSource)
        }

        let kuwoSource = buildKuwoSource()
        if !sources.contains(where: { $0.bookSourceUrl == kuwoSource.bookSourceUrl }) {
            toSave.append(kuwoSource)
        }

        if !toSave.isEmpty {
            try? await bookSourceRepository.saveSources(toSave)
        }
    }

    private func buildDefaultSampleSource() -> BookSource {
        BookSource(
            bookSourceUrl: "https://biquge.example.com",
            bookSourceName: "笔趣阁官方",
            bookSourceType: 0,
            exploreUrl: """
            玄幻奇幻::/sort/1_{{page}}.html
            武侠仙侠::/sort/2_{{page}}.html
            都市言情::/sort/3_{{page}}.html
            历史军事::/sort/4_{{page}}.html
            """,
            searchUrl: "/search.php?keyword={{key}}",
            bookSourceComment: "内置演示书源",
            ruleSearch: RuleSearch(
                checkKeyWord: "宿命",
                bookList: ".item",
                name: "dt a@text",
                author: "dt span@text",
                kind: ".book-kind@text",
                intro: ".intro@text",
                coverUrl: "img@src",
                bookUrl: "dt a@href"),
            ruleExplore: RuleExplore(
                bookList: ".item",
                name: "dt a@text",
                author: "dt span@text",
                kind: ".book-kind@text",
                intro: ".intro@text",
                coverUrl: "img@src",
                bookUrl: "dt a@href"),
            ruleBookInfo: RuleBookInfo(
                name: "h1.book-name@text",
                author: "span.author@text",
                intro: "p.intro@text"),
            ruleToc: RuleToc(
                chapterList: "ul.chapters li a",
                chapterName: "text",
                chapterUrl: "href"),
            ruleContent: RuleContent(
                content: "#content@text"))
    }

    private func buildKuwoSource() -> BookSource {
        BookSource(
            bookSourceUrl: "http://appi.kuwo.cn",
            bookSourceName: "酷我小说",
            bookSourceGroup: "API",
            bookSourceType: 0,
            header: "{\"User-Agent\": \"Dalvik/2.1.0 (Linux; U; Android 8.0.0; LND-AL40)\"}",
            searchUrl: "/novels/api/book/search?keyword={{key}}&pi={{page}}&ps=20",
            weight: 80,
            enabled: true,
            enabledExplore: false,
            customOrder: 1,
            ruleSearch: RuleSearch(
                checkKeyWord: "修仙",
                bookList: "$.data",
                name: "$.title",
                author: "$.author_name",
                kind: "{{$.category_name}},{{$.status}}",
                wordCount: "$.all_words",
                intro: "$.intro",
                coverUrl: "$.cover_url",
                bookUrl: "/novels/api/book/{{$.book_id}}"),
            ruleBookInfo: RuleBookInfo(
                bookInfoInit: "$.data",
                name: "$.title",
                author: "$.author_name",
                kind: "{{$.category_name}},{{$.status}}",
                wordCount: "$.all_words",
                intro: "$.intro",
                coverUrl: "$.cover_url",
                tocUrl: "/novels/api/book/{{$.book_id}}/chapters?paging=0"),
            ruleToc: RuleToc(
                chapterList: "$.data",
                chapterName: "$.chapter_title",
                chapterUrl: "/novels/api/book/{{$.book_id}}/chapters/{{$.chapter_id}}"),
            ruleContent: RuleContent(
                content: "$.data.content"))
    }

    private func seedSampleBookshelfIfNeeded() async {
        let books = (try? await bookRepository.getBookshelf()) ?? []
        guard books.isEmpty else { return }

        let sampleBook = Book(
            bookUrl: "https://biquge.example.com/book/circle_of_inevitability",
            tocUrl: "https://biquge.example.com/book/circle_of_inevitability/toc",
            origin: "https://biquge.example.com",
            originName: "笔趣阁官方",
            name: "宿命之环",
            author: "爱潜水的乌贼",
            kind: "连载中 奇幻 序列途径",
            coverUrl: "https://bookcover.yuewen.com/qdbimg/349573/1036370336/300.webp",
            intro: "诡秘之主第二部。四旬节的前夜，微风轻拂的夜晚，卢米安站在崖顶，眺望着科尔杜村...",
            latestChapterTitle: "第150章 最后的落幕",
            durChapterTitle: "第一章 宿命之始",
            durChapterIndex: 0,
            wordCount: "285万字")
        try? await bookRepository.saveBook(sampleBook)

        let chapters = [
            Chapter(url: "https://biquge.example.com/c1", title: "第一章 宿命之始", bookUrl: sampleBook.bookUrl, index: 0),
            Chapter(url: "https://biquge.example.com/c2", title: "第二章 科尔杜村的阴影", bookUrl: sampleBook.bookUrl, index: 1),
            Chapter(url: "https://biquge.example.com/c3", title: "第三章 恶作剧与神秘客", bookUrl: sampleBook.bookUrl, index: 2),
        ]
        try? await bookRepository.saveChapters(chapters, for: sampleBook.bookUrl)

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
            bookUrl: sampleBook.bookUrl,
            index: 0)
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
            bookRepository: bookRepository)
    }

    /// 创建书架 ViewModel
    public func makeBookshelfViewModel() -> BookshelfViewModel {
        BookshelfViewModel(
            getBookshelfUseCase: getBookshelfUseCase,
            removeBookFromShelfUseCase: removeBookFromShelfUseCase,
            checkBookUpdatesUseCase: checkBookUpdatesUseCase)
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
            bookRepository: bookRepository)
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
            debugSourceUseCase: debugBookSourceUseCase)
    }

    /// 创建系统设置 ViewModel
    public func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            backupUseCase: backupToWebDAVUseCase,
            restoreUseCase: restoreFromWebDAVUseCase)
    }
}
