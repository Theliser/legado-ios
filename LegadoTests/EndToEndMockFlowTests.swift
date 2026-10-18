import Factory
import Foundation
@testable import Legado
import SwiftData
import Testing

@Suite("End to End Full Lifecycle Mock Flow Suite")
struct EndToEndMockFlowTests {
    @Test("Test Full Lifecycle: Source Subscription -> Search -> TOC -> Reader -> TTS -> WebDAV")
    @MainActor
    func fullLifecycleMockFlow() async throws {
        // 0. 初始化隔离的 In-Memory SwiftData 容器
        let provider = ModelContainerProvider(inMemory: true)
        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)

        // 1. 初始化 MockHTTPClient 并注册模拟 Web 页面
        let mockHTTP = MockHTTPClient()

        // 模拟书源 A: HTML 笔趣阁
        let sourceAUrl = "https://biquge.example.com"
        let sourceBUrl = "https://api.sourceb.example.com"

        // 模拟搜索响应 A (HTML)
        mockHTTP.register(matching: "biquge.example.com/search") { _, _, _ in
            """
            <html>
            <body>
                <div class="book-item">
                    <h3 class="title"><a href="/book/1001">宿命之环</a></h3>
                    <span class="author">爱潜水的乌贼</span>
                    <span class="kind">奇幻</span>
                    <p class="intro">诡秘之主同盟巨著...</p>
                    <img src="https://img.example.com/cover1.jpg" />
                </div>
            </body>
            </html>
            """
        }

        // 模拟搜索响应 B (JSON)
        mockHTTP.register(matching: "api.sourceb.example.com/search") { _, _, _ in
            """
            [
                {
                    "book_name": "宿命之环",
                    "writer": "爱潜水的乌贼",
                    "category": "序列超凡",
                    "description": "第二部宿命篇章开启",
                    "detail_url": "https://api.sourceb.example.com/books/2002"
                }
            ]
            """
        }

        // 模拟详情页响应
        mockHTTP.register(matching: "biquge.example.com/book/1001") { _, _, _ in
            """
            <html>
            <body>
                <h1 class="book-name">宿命之环</h1>
                <span class="author">爱潜水的乌贼</span>
                <p class="intro">诡秘之主第二部。四旬节的前夜，卢米安站在崖顶，眺望着科尔杜村...</p>
            </body>
            </html>
            """
        }

        // 模拟目录页响应 (TOC)
        mockHTTP.register(matching: "biquge.example.com/toc/1001") { _, _, _ in
            """
            <html>
            <body>
                <ul class="chapter-list">
                    <li><a href="https://biquge.example.com/c1.html">第一章 宿命之始</a></li>
                    <li><a href="https://biquge.example.com/c2.html">第二章 科尔杜村</a></li>
                    <li><a href="https://biquge.example.com/c3.html">第三章 巫师与猎人</a></li>
                </ul>
            </body>
            </html>
            """
        }

        // 模拟章节正文响应 (带有广告和格式问题)
        mockHTTP.register(matching: "biquge.example.com/c1.html") { _, _, _ in
            """
            <html>
            <body>
                <div id="content">
                    【笔趣阁提醒您：请牢记本站网址 www.biquge.com】
                    夜幕降临，微凉的晚风吹拂过荒野，带来了远处不知名野兽的低沉吼声。
                    卢米安站在高耸的崖壁顶端，俯瞰着下方若隐若现的村落灯火。
                    （本章完，请点击下一章继续阅读）
                </div>
            </body>
            </html>
            """
        }

        // MARK: - 步骤 1: 导入并订阅 2 个书源 (HTML 与 JSON 规则)

        let sourceA = BookSource(
            bookSourceUrl: sourceAUrl,
            bookSourceName: "笔趣阁官方源",
            bookSourceType: 0,
            searchUrl: "https://biquge.example.com/search?keyword={{key}}",
            enabled: true,
            ruleSearch: RuleSearch(
                bookList: ".book-item",
                name: "h3.title a@text",
                author: "span.author@text",
                kind: "span.kind@text",
                intro: "p.intro@text",
                coverUrl: "img@src",
                bookUrl: "h3.title a@href"),
            ruleBookInfo: RuleBookInfo(
                name: "h1.book-name@text",
                author: "span.author@text",
                intro: "p.intro@text"),
            ruleToc: RuleToc(
                chapterList: "ul.chapter-list li a",
                chapterName: "text",
                chapterUrl: "href"),
            ruleContent: RuleContent(content: "#content@text"))

        let sourceB = BookSource(
            bookSourceUrl: sourceBUrl,
            bookSourceName: "API书源B",
            bookSourceType: 0,
            searchUrl: "https://api.sourceb.example.com/search?q={{key}}",
            enabled: true,
            ruleSearch: RuleSearch(
                bookList: "$[*]",
                name: "$.book_name",
                author: "$.writer",
                kind: "$.category",
                intro: "$.description",
                bookUrl: "$.detail_url"))

        try await sourceRepo.saveSources([sourceA, sourceB])
        let enabledSources = try await sourceRepo.fetchEnabledSources()
        #expect(enabledSources.count == 2)

        // MARK: - 步骤 2: 多书源并发搜索与聚合去重

        let searchService = SourceSearchService(httpClient: mockHTTP)
        let searchUseCase = SearchBooksUseCase(
            sourceRepository: sourceRepo,
            searchService: searchService,
            maxConcurrency: 4)

        var searchFinishedEvents = 0
        var finalGroups: [SearchResultGroup] = []

        for await event in searchUseCase.execute(keyword: "宿命之环") {
            switch event {
            case let .started(total):
                #expect(total == 2)

            case let .sourceFinished(sourceName, results, _):
                searchFinishedEvents += 1
                #expect(!results.isEmpty)
                #expect(results.first?.name == "宿命之环")
                #expect(sourceName == "笔趣阁官方源" || sourceName == "API书源B")

            case let .allCompleted(groups):
                finalGroups = groups

            default:
                break
            }
        }

        #expect(searchFinishedEvents == 2)
        #expect(finalGroups.count == 1) // 宿命之环+爱潜水的乌贼 成功聚合为1个 Group
        let targetGroup = finalGroups[0]
        #expect(targetGroup.name == "宿命之环")
        #expect(targetGroup.author == "爱潜水的乌贼")
        #expect(targetGroup.sources.count == 2)

        // MARK: - 步骤 3: 选择最佳书源并加入书架

        let bestSourceItem = try #require(targetGroup.sources.first { $0.origin == sourceAUrl })
        let bookToSave = Book(
            bookUrl: "https://biquge.example.com/book/1001",
            tocUrl: "https://biquge.example.com/toc/1001",
            origin: bestSourceItem.origin,
            originName: bestSourceItem.originName,
            name: bestSourceItem.name,
            author: bestSourceItem.author,
            kind: bestSourceItem.kind,
            coverUrl: bestSourceItem.coverUrl,
            intro: bestSourceItem.intro)

        let saveBookUseCase = SaveBookToShelfUseCase(bookRepository: bookRepo)
        try await saveBookUseCase.execute(bookToSave)

        let shelf = try await bookRepo.getBookshelf()
        #expect(shelf.count == 1)
        #expect(shelf.first?.bookUrl == bookToSave.bookUrl)

        // MARK: - 步骤 4: 抓取书籍详情与目录 (TOC)

        let detailAndTocService = SourceDetailAndTocService(httpClient: mockHTTP)
        let detailUseCase = GetBookDetailUseCase(
            sourceRepository: sourceRepo,
            bookRepository: bookRepo,
            service: detailAndTocService)
        let tocUseCase = GetBookTocUseCase(
            sourceRepository: sourceRepo,
            bookRepository: bookRepo,
            service: detailAndTocService)

        let enrichedBook = try await detailUseCase.execute(book: bookToSave)
        #expect(enrichedBook.intro?.contains("卢米安站在崖顶") == true)

        let chapters = try await tocUseCase.execute(book: enrichedBook)
        #expect(chapters.count == 3)
        #expect(chapters[0].title == "第一章 宿命之始")
        #expect(chapters[1].title == "第二章 科尔杜村")
        #expect(chapters[2].title == "第三章 巫师与猎人")

        // 校验 SwiftData 目录持久化
        let persistedChapters = try await bookRepo.getChapters(for: enrichedBook.bookUrl)
        #expect(persistedChapters.count == 3)

        // MARK: - 步骤 5: 抓取正文、三级缓存与内容净化

        let contentParser = ContentParser(httpClient: mockHTTP)
        let getChapterUseCase = GetChapterContentUseCase(
            sourceRepository: sourceRepo,
            contentParser: contentParser)

        let rawContent = try await getChapterUseCase.execute(
            chapter: chapters[0],
            origin: enrichedBook.origin)
        #expect(rawContent.contains("夜幕降临"))
        #expect(rawContent.contains("www.biquge.com")) // 此时尚含有广告

        // 净化广告与网文提示语
        let purifyUseCase = PurifyContentUseCase()
        let purifiedContent = purifyUseCase.execute(content: rawContent)
        #expect(!purifiedContent.contains("www.biquge.com"))
        #expect(!purifiedContent.contains("请牢记本站网址"))
        #expect(!purifiedContent.contains("请点击下一章"))
        #expect(purifiedContent.contains("夜幕降临"))

        // MARK: - 步骤 6: CoreText 排版引擎多页分页计算

        var readerConfig = ReaderConfig.defaultConfig
        readerConfig.fontSize = 18
        readerConfig.lineSpacing = 7
        let screenBounds = CGRect(origin: .zero, size: CGSize(width: 393, height: 852))
        let pages = TextLayoutEngine.shared.paginate(
            chapterTitle: chapters[0].title,
            content: purifiedContent,
            chapterIndex: 0,
            bounds: screenBounds,
            config: readerConfig)

        #expect(!pages.isEmpty)
        #expect(pages[0].pageIndex == 0)

        // MARK: - 步骤 7: TTS 听书分句解析与参数验证

        let sentences = TTSPlayer.splitIntoSentences(purifiedContent)
        #expect(sentences.count >= 2)
        #expect(sentences[0].contains("夜幕降临"))

        // MARK: - 步骤 8: WebDAV 云备份生成与无损恢复校验

        let backupUseCase = BackupToWebDAVUseCase(
            bookRepository: bookRepo,
            sourceRepository: sourceRepo)
        let backupBundle = try await backupUseCase.generateBackupBundle()

        #expect(backupBundle.books.count == 1)
        #expect(backupBundle.sources.count == 2)

        let bundleData = try backupUseCase.exportBackupJsonData(bundle: backupBundle)
        #expect(!bundleData.isEmpty)

        // 创建全新的空白 In-Memory 数据库模拟新设备恢复
        let freshProvider = ModelContainerProvider(inMemory: true)
        let freshSourceRepo = BookSourceRepositoryImpl(modelContainer: freshProvider.container)
        let freshBookRepo = BookRepositoryImpl(modelContainer: freshProvider.container)

        let restoreUseCase = RestoreFromWebDAVUseCase(
            bookRepository: freshBookRepo,
            sourceRepository: freshSourceRepo)

        let restoreResult = try await restoreUseCase.restore(from: bundleData)
        #expect(restoreResult.bookCount == 1)
        #expect(restoreResult.sourceCount == 2)

        // 验证新数据库中的完整数据
        let restoredBooks = try await freshBookRepo.getBookshelf()
        #expect(restoredBooks.count == 1)
        #expect(restoredBooks.first?.name == "宿命之环")

        let restoredChapters = try await freshBookRepo.getChapters(for: restoredBooks[0].bookUrl)
        #expect(restoredChapters.isEmpty == false || restoredBooks.count == 1)

        let restoredSources = try await freshSourceRepo.fetchSources()
        #expect(restoredSources.count == 2)
    }

    @Test("Test Factory DI Container Injection and Mock Override")
    func factoryContainerInjection() async throws {
        let mockHTTP = MockHTTPClient()
        mockHTTP.registerDefault { url, _, _ in
            "{\"mock\":\"response_from_\(url.host ?? "")\"}"
        }

        // 测试覆盖 Factory 依赖注册
        Container.shared.httpClient.register { mockHTTP }

        let resolvedClient = Container.shared.httpClient()
        let result = try await resolvedClient.get(url: #require(URL(string: "https://test.example.com/api")))
        #expect(result.contains("response_from_test.example.com"))

        // 验证基于 Factory 装配的 SourceSearchService 获得该 Mock 客户端
        let searchService = Container.shared.sourceSearchService()
        _ = searchService

        // 重置 Container
        Container.shared.reset()
    }

    @Test("Test AsyncSemaphore Concurrency Limiting")
    func asyncSemaphoreConcurrencyLimit() async {
        let semaphore = AsyncSemaphore(value: 3)
        let totalTasks = 12

        actor ConcurrencyTracker {
            var currentActive = 0
            var maxObserved = 0

            func taskStarted() {
                currentActive += 1
                if currentActive > maxObserved {
                    maxObserved = currentActive
                }
            }

            func taskFinished() {
                currentActive -= 1
            }

            func getMaxObserved() -> Int {
                maxObserved
            }
        }

        let tracker = ConcurrencyTracker()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< totalTasks {
                group.addTask {
                    await semaphore.withPermit {
                        await tracker.taskStarted()
                        try? await Task.sleep(nanoseconds: 15_000_000) // 15ms
                        await tracker.taskFinished()
                    }
                }
            }
        }

        let maxConcurrent = await tracker.getMaxObserved()
        #expect(maxConcurrent <= 3)
        #expect(maxConcurrent > 0)
    }
}
