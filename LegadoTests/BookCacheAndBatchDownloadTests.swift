import Foundation
@testable import Legado
import Testing

@Suite("Book Cache and Batch Download Suite")
struct BookCacheAndBatchDownloadTests {
    @Test("Test BookCacheRepository CRUD and Size Calculations")
    func bookCacheRepositoryCRUD() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestCache_\(UUID().uuidString)", isDirectory: true)
        let repository = BookCacheRepositoryImpl(baseDirectory: tempDir)
        let bookUrl = "https://example.com/test_book"

        #expect(!repository.isChapterCached(bookUrl: bookUrl, index: 0))

        // 1. 写入离线章节
        try repository.saveChapterContent(bookUrl: bookUrl, index: 0, content: "第一章 始于微末")
        try repository.saveChapterContent(bookUrl: bookUrl, index: 1, content: "第二章 潜龙在渊")
        try repository.saveChapterContent(bookUrl: bookUrl, index: 2, content: "第三章 惊鸿一瞥")

        // 2. 读取与命中检验
        #expect(repository.isChapterCached(bookUrl: bookUrl, index: 0))
        #expect(repository.isChapterCached(bookUrl: bookUrl, index: 1))
        #expect(!repository.isChapterCached(bookUrl: bookUrl, index: 99))

        let ch0 = repository.getCachedChapterContent(bookUrl: bookUrl, index: 0)
        #expect(ch0 == "第一章 始于微末")

        let indices = repository.getCachedChapterIndices(bookUrl: bookUrl)
        #expect(indices.count == 3)
        #expect(indices.contains(0))
        #expect(indices.contains(1))
        #expect(indices.contains(2))

        // 3. 统计容量与信息
        let size = repository.calculateBookCacheSize(bookUrl: bookUrl)
        #expect(size > 0)

        let info = repository.getBookCacheInfo(bookUrl: bookUrl, totalChapters: 10)
        #expect(info.cachedCount == 3)
        #expect(info.totalCount == 10)
        #expect(info.percentage == 30)
        #expect(!info.formattedSize.isEmpty)

        // 4. 清除本书缓存
        try repository.clearBookCache(bookUrl: bookUrl)
        #expect(repository.getCachedChapterIndices(bookUrl: bookUrl).isEmpty)
        #expect(repository.calculateBookCacheSize(bookUrl: bookUrl) == 0)

        // 清理临时测试文件夹
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Test BatchDownloadChaptersUseCase Target Range Calculations")
    func batchRangeCalculations() {
        let book = Book(bookUrl: "https://b.com", name: "测试书", author: "测试作者", durChapterIndex: 20)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestCache_\(UUID().uuidString)", isDirectory: true)
        let repo = BookCacheRepositoryImpl(baseDirectory: tempDir)
        let contentUseCase = GetChapterContentUseCase(
            sourceRepository: BookSourceRepositoryImpl(modelContainer: ModelContainerProvider(inMemory: true).container),
            cacheRepository: repo)
        let batchUseCase = BatchDownloadChaptersUseCase(
            getChapterContentUseCase: contentUseCase,
            bookCacheRepository: repo)

        // 后 50 章 (20 ~ 69)
        let r50 = batchUseCase.calculateTargetRange(book: book, totalCount: 200, option: .next50)
        #expect(r50.lowerBound == 20)
        #expect(r50.upperBound == 69)

        // 后 100 章 (20 ~ 119)
        let r100 = batchUseCase.calculateTargetRange(book: book, totalCount: 200, option: .next100)
        #expect(r100.lowerBound == 20)
        #expect(r100.upperBound == 119)

        // 全部未读 (20 ~ 199)
        let rUnread = batchUseCase.calculateTargetRange(book: book, totalCount: 200, option: .allUnread)
        #expect(rUnread.lowerBound == 20)
        #expect(rUnread.upperBound == 199)

        // 全本缓存 (0 ~ 199)
        let rAll = batchUseCase.calculateTargetRange(book: book, totalCount: 200, option: .all)
        #expect(rAll.lowerBound == 0)
        #expect(rAll.upperBound == 199)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Test BatchDownloadChaptersUseCase Concurrent Execution")
    func batchDownloadExecution() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestCache_\(UUID().uuidString)", isDirectory: true)
        let cacheRepo = BookCacheRepositoryImpl(baseDirectory: tempDir)

        let provider = ModelContainerProvider(inMemory: true)
        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)

        // 预设书源
        let source = BookSource(
            bookSourceUrl: "https://mock.com",
            bookSourceName: "MockSource",
            bookSourceType: 0)
        try await sourceRepo.saveSources([source])

        let contentUseCase = GetChapterContentUseCase(
            sourceRepository: sourceRepo,
            cacheRepository: cacheRepo)
        let batchUseCase = BatchDownloadChaptersUseCase(
            getChapterContentUseCase: contentUseCase,
            bookCacheRepository: cacheRepo)

        let book = Book(bookUrl: "https://mock.com/book", origin: "https://mock.com", name: "并发测试小说", author: "测试作者")
        let chapters = [
            Chapter(url: "https://mock.com/ch0", title: "第0章", bookUrl: book.bookUrl, index: 0),
            Chapter(url: "https://mock.com/ch1", title: "第1章", bookUrl: book.bookUrl, index: 1),
            Chapter(url: "https://mock.com/ch2", title: "第2章", bookUrl: book.bookUrl, index: 2),
        ]

        // 预写入 ch0，确保 uncached 过滤正常
        try cacheRepo.saveChapterContent(bookUrl: book.bookUrl, index: 0, content: "已存在缓存")

        // 批量缓存，预注入 ch1 和 ch2
        try cacheRepo.saveChapterContent(bookUrl: book.bookUrl, index: 1, content: "正文1")
        try cacheRepo.saveChapterContent(bookUrl: book.bookUrl, index: 2, content: "正文2")

        var lastProgress: BatchDownloadProgress?
        try await batchUseCase.execute(
            book: book,
            chapters: chapters,
            option: .all,
            concurrency: 2) { progress in
                lastProgress = progress
            }

        #expect(lastProgress?.status == .completed)
        #expect(cacheRepo.getCachedChapterIndices(bookUrl: book.bookUrl).count == 3)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Test BookDetailViewModel Cache Intents")
    @MainActor
    func bookDetailViewModelCache() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestCache_\(UUID().uuidString)", isDirectory: true)
        let cacheRepo = BookCacheRepositoryImpl(baseDirectory: tempDir)
        let manageCacheUseCase = ManageBookCacheUseCase(bookCacheRepository: cacheRepo)
        let contentUseCase = GetChapterContentUseCase(sourceRepository: sourceRepo, cacheRepository: cacheRepo)
        let batchUseCase = BatchDownloadChaptersUseCase(
            getChapterContentUseCase: contentUseCase,
            bookCacheRepository: cacheRepo)

        let book = Book(bookUrl: "https://example.com/b1", name: "诡秘之主", author: "乌贼")
        try await bookRepo.saveBook(book)
        try cacheRepo.saveChapterContent(bookUrl: book.bookUrl, index: 0, content: "第一章 绯红")

        let vm = BookDetailViewModel(
            book: book,
            getBookDetailUseCase: GetBookDetailUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo),
            getBookTocUseCase: GetBookTocUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo),
            saveBookToShelfUseCase: SaveBookToShelfUseCase(bookRepository: bookRepo),
            removeBookFromShelfUseCase: RemoveBookFromShelfUseCase(bookRepository: bookRepo),
            bookRepository: bookRepo,
            batchDownloadChaptersUseCase: batchUseCase,
            manageBookCacheUseCase: manageCacheUseCase)

        // 1. 打开离线缓存弹窗
        #expect(!vm.state.isCacheSheetPresented)
        vm.send(.toggleCacheSheet(true))
        #expect(vm.state.isCacheSheetPresented)

        // 2. 检查缓存信息已同步
        vm.send(.refreshCacheInfo)
        #expect(vm.state.cacheInfo?.cachedCount == 1)

        // 3. 清理缓存
        vm.send(.clearBookCache)
        #expect(vm.state.cacheInfo?.cachedCount == 0)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Test SettingsViewModel Cache Clean Intent")
    @MainActor
    func settingsViewModelCache() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestCache_\(UUID().uuidString)", isDirectory: true)
        let cacheRepo = BookCacheRepositoryImpl(baseDirectory: tempDir)
        let manageCacheUseCase = ManageBookCacheUseCase(bookCacheRepository: cacheRepo)

        try cacheRepo.saveChapterContent(bookUrl: "https://book.com/1", index: 0, content: "大量离线正文缓存...")
        #expect(manageCacheUseCase.calculateTotalCacheSize() > 0)

        let provider = ModelContainerProvider(inMemory: true)
        let vm = SettingsViewModel(
            backupUseCase: BackupToWebDAVUseCase(
                bookRepository: BookRepositoryImpl(modelContainer: provider.container),
                sourceRepository: BookSourceRepositoryImpl(modelContainer: provider.container)),
            restoreUseCase: RestoreFromWebDAVUseCase(
                bookRepository: BookRepositoryImpl(modelContainer: provider.container),
                sourceRepository: BookSourceRepositoryImpl(modelContainer: provider.container)),
            manageBookCacheUseCase: manageCacheUseCase)

        #expect(vm.state.cacheSizeBytes > 0)
        #expect(!vm.state.formattedCacheSize.isEmpty)

        // 清理全部缓存
        vm.send(.clearAllCache)
        #expect(vm.state.cacheSizeBytes == 0)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
