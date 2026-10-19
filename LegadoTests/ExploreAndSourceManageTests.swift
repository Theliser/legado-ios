import Foundation
@testable import Legado
import SwiftData
import Testing

@Suite("Explore and Source Management Suite")
struct ExploreAndSourceManageTests {
    @Test("Test Explore Category Text Parsing")
    func exploreCategoryTextParsing() {
        let textConfig = """
        玄幻奇幻::/sort/1_{{page}}.html
        武侠修真::/sort/2_{{page}}.html
        都市爽文::https://example.com/sort/3_{{page}}.html
        """

        let source = BookSource(
            bookSourceUrl: "https://biquge.example.com",
            bookSourceName: "笔趣阁",
            exploreUrl: textConfig)

        let categories = SourceExploreService.shared.parseCategories(source: source)
        #expect(categories.count == 3)
        #expect(categories[0].title == "玄幻奇幻")
        #expect(categories[0].categoryUrl == "/sort/1_{{page}}.html")
        #expect(categories[1].title == "武侠修真")
        #expect(categories[2].categoryUrl == "https://example.com/sort/3_{{page}}.html")
    }

    @Test("Test Explore Category JSON Parsing")
    func exploreCategoryJsonParsing() {
        let jsonConfig = """
        [
            {"title": "男生热门", "url": "/ranking/male"},
            {"title": "女生精选", "url": "/ranking/female"}
        ]
        """

        let source = BookSource(
            bookSourceUrl: "https://example.com",
            bookSourceName: "书源A",
            exploreUrl: jsonConfig)

        let categories = SourceExploreService.shared.parseCategories(source: source)
        #expect(categories.count == 2)
        #expect(categories[0].title == "男生热门")
        #expect(categories[0].categoryUrl == "/ranking/male")
        #expect(categories[1].title == "女生精选")
        #expect(categories[1].categoryUrl == "/ranking/female")
    }

    @Test("Test Explore HTML Books Extraction")
    func exploreBooksHtmlParsing() {
        let html = """
        <html>
            <body>
                <div class="list">
                    <div class="item">
                        <a class="name" href="/book/101">万相之王</a>
                        <span class="author">天蚕土豆</span>
                        <span class="category">东方玄幻</span>
                        <p class="desc">李洛的天赋与相性之路...</p>
                        <img src="/cover/101.jpg" />
                    </div>
                    <div class="item">
                        <a class="name" href="/book/102">深空彼岸</a>
                        <span class="author">辰东</span>
                        <span class="category">都市异能</span>
                        <p class="desc">浩瀚星空与旧土神话...</p>
                        <img src="/cover/102.jpg" />
                    </div>
                </div>
            </body>
        </html>
        """

        let source = BookSource(
            bookSourceUrl: "https://example.com",
            bookSourceName: "测试源",
            ruleExplore: RuleExplore(
                bookList: ".item",
                name: "a.name@text",
                author: "span.author@text",
                intro: "p.desc@text",
                kind: "span.category@text",
                bookUrl: "a.name@href",
                coverUrl: "img@src"))

        let books = SourceExploreService.shared.parseBooks(
            content: html,
            source: source,
            baseUrl: "https://example.com/category/1")

        #expect(books.count == 2)
        #expect(books[0].name == "万相之王")
        #expect(books[0].author == "天蚕土豆")
        #expect(books[0].kind == "东方玄幻")
        #expect(books[0].bookUrl == "https://example.com/book/101")
        #expect(books[0].coverUrl == "https://example.com/cover/101.jpg")
        #expect(books[0].intro?.contains("李洛") == true)

        #expect(books[1].name == "深空彼岸")
        #expect(books[1].author == "辰东")
    }

    @Test("Test Import Book Sources from JSON")
    func importBookSourcesFromJson() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let repo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let importUseCase = ImportBookSourcesUseCase(sourceRepository: repo)

        let json = """
        [
            {
                "bookSourceUrl": "https://source1.example.com",
                "bookSourceName": "书源一号",
                "bookSourceType": 0,
                "ruleSearch": {
                    "bookList": ".item"
                }
            },
            {
                "bookSourceUrl": "https://source2.example.com",
                "bookSourceName": "书源二号",
                "bookSourceType": 0
            }
        ]
        """

        let count = try await importUseCase.execute(input: json)
        #expect(count == 2)

        let sources = try await repo.fetchSources()
        #expect(sources.count == 2)
        #expect(sources.contains(where: { $0.bookSourceName == "书源一号" }))
        #expect(sources.contains(where: { $0.bookSourceName == "书源二号" }))
    }

    @Test("Test Toggle and Delete Book Source")
    func toggleAndDeleteBookSource() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let repo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let toggleUseCase = ToggleBookSourceEnabledUseCase(sourceRepository: repo)
        let deleteUseCase = DeleteBookSourceUseCase(sourceRepository: repo)

        let source = BookSource(
            bookSourceUrl: "https://test.example.com",
            bookSourceName: "可编辑源",
            enabled: true)
        try await repo.saveSources([source])

        try await toggleUseCase.execute(sourceUrl: source.bookSourceUrl, enabled: false)
        let sourcesAfterToggle = try await repo.fetchSources()
        #expect(sourcesAfterToggle.first?.enabled == false)

        try await deleteUseCase.execute(sourceUrl: source.bookSourceUrl)
        let sourcesAfterDelete = try await repo.fetchSources()
        #expect(sourcesAfterDelete.isEmpty)
    }

    @Test("Test Debug Book Source Diagnostics")
    func debugBookSourceDiagnostics() async {
        let debugUseCase = DebugBookSourceUseCase()
        let source = BookSource(
            bookSourceUrl: "https://mock.example.com",
            bookSourceName: "诊断书源",
            searchUrl: "https://mock.example.com/search?q={{key}}")

        let report = await debugUseCase.execute(source: source, keyword: "剑来")
        #expect(report.sourceName == "诊断书源")
        #expect(!report.logs.isEmpty)
        #expect(report.logs.first?.message.contains("开始调试") == true)
    }
}
