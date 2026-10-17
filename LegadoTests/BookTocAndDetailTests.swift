import Foundation
@testable import Legado
import SwiftData

// SwiftSoup test helper
import SwiftSoup
import Testing

@Suite("Book Detail and TOC Suite")
struct BookTocAndDetailTests {
    @Test("Test HTML Book Detail Parsing")
    func htmlBookDetailParsing() throws {
        let html = """
        <html>
            <head><title>书籍详情</title></head>
            <body>
                <div class="book-info">
                    <h1 class="book-name">宿命之环</h1>
                    <span class="author">爱潜水的乌贼</span>
                    <span class="kind">奇幻修真</span>
                    <span class="words">250万字</span>
                    <img class="cover" src="/covers/ring.jpg" />
                    <p class="intro">诡秘之主第二部，展现新的序列与命运之轮...</p>
                    <a class="latest" href="/chapter/500">第五百章 命运的织线</a>
                    <a class="toc-link" href="/book/123/catalog">完整目录</a>
                </div>
            </body>
        </html>
        """

        let ruleInfo = RuleBookInfo(
            name: "h1.book-name@text",
            author: "span.author@text",
            kind: "span.kind@text",
            wordCount: "span.words@text",
            lastChapter: "a.latest@text",
            intro: "p.intro@text",
            coverUrl: "img.cover@src",
            tocUrl: "a.toc-link@href")

        let doc = try SwiftSoupParserHelper.parseHtml(html, baseUrl: "https://biquge.example.com/book/123")
        let parsedName = CSSSelectorParser.parseSingle(element: doc, rule: ruleInfo.name ?? "", baseUrl: "https://biquge.example.com/book/123")
        let parsedAuthor = CSSSelectorParser.parseSingle(element: doc, rule: ruleInfo.author ?? "", baseUrl: "https://biquge.example.com/book/123")
        let parsedCover = CSSSelectorParser.parseSingle(element: doc, rule: ruleInfo.coverUrl ?? "", baseUrl: "https://biquge.example.com/book/123")
        let parsedIntro = CSSSelectorParser.parseSingle(element: doc, rule: ruleInfo.intro ?? "", baseUrl: "https://biquge.example.com/book/123")
        let parsedLatest = CSSSelectorParser.parseSingle(element: doc, rule: ruleInfo.lastChapter ?? "", baseUrl: "https://biquge.example.com/book/123")

        #expect(parsedName == "宿命之环")
        #expect(parsedAuthor == "爱潜水的乌贼")
        #expect(parsedCover == "https://biquge.example.com/covers/ring.jpg")
        #expect(parsedIntro?.contains("命运之轮") == true)
        #expect(parsedLatest == "第五百章 命运的织线")
    }

    @Test("Test HTML TOC Chapter List Parsing and Reverse")
    func htmlTocParsingAndReverse() throws {
        let tocHtml = """
        <html>
            <body>
                <ul class="chapters">
                    <li><a href="/c1.html">第一章 远方的信件</a></li>
                    <li><a href="/c2.html">第二章 灰雾之上</a></li>
                    <li><a href="/c3.html">第三章 占卜家</a></li>
                </ul>
            </body>
        </html>
        """

        let doc = try SwiftSoupParserHelper.parseHtml(tocHtml, baseUrl: "https://biquge.example.com")
        let elements = try doc.select("ul.chapters li")
        #expect(elements.count == 3)

        var chapters: [Chapter] = []
        for (i, elem) in elements.enumerated() {
            let title = CSSSelectorParser.parseSingle(element: elem, rule: "a@text", baseUrl: "https://biquge.example.com") ?? ""
            let url = CSSSelectorParser.parseSingle(element: elem, rule: "a@href", baseUrl: "https://biquge.example.com") ?? ""
            chapters.append(Chapter(url: url, title: title, bookUrl: "https://biquge.example.com/book/1", index: i))
        }

        #expect(chapters.count == 3)
        #expect(chapters[0].title == "第一章 远方的信件")
        #expect(chapters[0].url == "https://biquge.example.com/c1.html")
        #expect(chapters[2].title == "第三章 占卜家")

        // Reversal test
        chapters.reverse()
        for i in chapters.indices {
            chapters[i].index = i
        }
        #expect(chapters[0].title == "第三章 占卜家")
        #expect(chapters[2].title == "第一章 远方的信件")
    }

    @Test("Test GetBookTocUseCase with Local Caching")
    func getBookTocUseCaseLocalCache() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)

        let book = Book(
            bookUrl: "https://example.com/book/test",
            name: "缓存测试书",
            author: "测试作者")
        try await bookRepo.saveBook(book)

        let cachedChapters = [
            Chapter(url: "https://example.com/c1", title: "第一章", bookUrl: book.bookUrl, index: 0),
            Chapter(url: "https://example.com/c2", title: "第二章", bookUrl: book.bookUrl, index: 1),
        ]
        try await bookRepo.saveChapters(cachedChapters, for: book.bookUrl)

        let useCase = GetBookTocUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo)
        let result = try await useCase.execute(book: book, forceRefresh: false)

        #expect(result.count == 2)
        #expect(result[0].title == "第一章")
    }
}

enum SwiftSoupParserHelper {
    static func parseHtml(_ html: String, baseUrl: String) throws -> Document {
        try SwiftSoup.parse(html, baseUrl)
    }
}
