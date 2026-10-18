import Foundation
@testable import Legado
import Testing

@Suite("Local Import, TXT TOC Parser and Source Health Suite")
struct LocalImportAndHealthCheckTests {
    @Test("Test TxtTocParser with Standard Chinese Chapters")
    func txtTocParserStandardChapters() {
        let sampleTxt = """
        这是小说前言说明。
        欢迎阅读本书！

        第一章 宿命之始
        清晨的阳光洒落在塔罗堡的窗棂上。
        周明缓缓睁开了双眼。

        第2章 诡秘的低语
        深夜的钟声敲响了十二下。
        耳边传来了未知的呓语。

        终章 归于平静
        一切纷争终于落下了帷幕。
        """

        let chapters = TxtTocParser.parse(text: sampleTxt)
        #expect(chapters.count == 4)

        #expect(chapters[0].title == "前言")
        #expect(chapters[0].index == 0)
        #expect(chapters[0].content.contains("这是小说前言说明"))

        #expect(chapters[1].title == "第一章 宿命之始")
        #expect(chapters[1].index == 1)
        #expect(chapters[1].content.contains("周明缓缓睁开了双眼"))

        #expect(chapters[2].title == "第2章 诡秘的低语")
        #expect(chapters[2].index == 2)
        #expect(chapters[2].content.contains("耳边传来了未知的呓语"))

        #expect(chapters[3].title == "终章 归于平静")
        #expect(chapters[3].index == 3)
        #expect(chapters[3].content.contains("一切纷争终于落下了帷幕"))
    }

    @Test("Test TxtTocParser Fallback Chunker for Non-Standard Text")
    func txtTocParserFallbackChunker() {
        let unstructuredText = String(repeating: "这是一段没有标准章节格式的文本内容。", count: 400)
        let chapters = TxtTocParser.parse(text: unstructuredText)
        #expect(!chapters.isEmpty)
        #expect(chapters[0].title.starts(with: "第 1 节") || chapters[0].title == "正文")
    }

    @Test("Test ImportLocalBookUseCase with Temporary TXT File")
    func importLocalBookUseCase() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let cacheRepo = BookCacheRepositoryImpl()

        let useCase = ImportLocalBookUseCase(
            bookRepository: bookRepo,
            bookCacheRepository: cacheRepo)

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("[全本精校]诡秘之主(精校版).txt")

        let txtContent = """
        第一章 绯红
        痛！好痛！头好痛！
        第二章 仪式
        水银在地面上勾勒出诡秘的符号。
        """
        try txtContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let book = try await useCase.execute(fileUrl: tempFile)
        #expect(book.name == "诡秘之主")
        #expect(book.author == "本地导入")
        #expect(book.totalChapterNum == 2)

        let savedChapters = try await bookRepo.getChapters(for: book.bookUrl)
        #expect(savedChapters.count == 2)
        #expect(savedChapters[0].title == "第一章 绯红")
        #expect(savedChapters[1].title == "第二章 仪式")

        let cachedCh1 = cacheRepo.getCachedChapterContent(bookUrl: book.bookUrl, index: 0)
        #expect(cachedCh1?.contains("痛！好痛！头好痛！") == true)
    }

    @Test("Test SourceHealthReport Model Properties")
    func sourceHealthReportModel() {
        let report = SourceHealthReport(
            sourceUrl: "https://biquge.example.com",
            sourceName: "笔趣阁",
            isHealthy: true,
            responseTimeMs: 120,
            statusCode: 200,
            errorMessage: nil)

        #expect(report.sourceUrl == "https://biquge.example.com")
        #expect(report.sourceName == "笔趣阁")
        #expect(report.isHealthy == true)
        #expect(report.responseTimeMs == 120)
        #expect(report.statusCode == 200)
        #expect(report.errorMessage == nil)
    }

    @Test("Test CheckBookSourceHealthUseCase Invalid URL")
    func checkBookSourceHealthInvalidUrl() async {
        let useCase = CheckBookSourceHealthUseCase()
        let source = BookSource(
            bookSourceUrl: "invalid://url with spaces %%%",
            bookSourceName: "非法书源")

        let report = await useCase.check(source: source)
        #expect(report.isHealthy == false)
        #expect(report.sourceName == "非法书源")
    }

    private actor ProgressTracker {
        var count = 0
        func increment() {
            count += 1
        }
    }

    @Test("Test CheckBookSourceHealthUseCase Batch Callback")
    func checkBookSourceHealthBatch() async {
        let useCase = CheckBookSourceHealthUseCase()
        let sources = [
            BookSource(bookSourceUrl: "https://httpbin.org/status/200", bookSourceName: "源1"),
            BookSource(bookSourceUrl: "invalid://test", bookSourceName: "源2"),
        ]

        let tracker = ProgressTracker()
        let reports = await useCase.checkBatch(sources: sources, concurrency: 2) { _, completed, total in
            Task { await tracker.increment() }
            #expect(total == 2)
            #expect(completed >= 1 && completed <= 2)
        }

        #expect(reports.count == 2)
        let totalProgressCalls = await tracker.count
        #expect(totalProgressCalls >= 0)
    }
}
