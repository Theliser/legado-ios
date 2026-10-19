import Foundation
@testable import Legado
import XCTest

final class AndroidDataLayerParityTests: XCTestCase {

    // MARK: - Mock HTTP Client for Data Layer Verification

    private final class MockParityHttpClient: HTTPClientProtocol, @unchecked Sendable {
        var handler: ((AnalyzeUrl) async throws -> String)?

        func get(
            url: URL,
            headers _: [String: String]?,
            timeout _: TimeInterval) async throws -> String {
            if let handler {
                let analyzeUrl = try AnalyzeUrl(rawUrl: url.absoluteString)
                return try await handler(analyzeUrl)
            }
            return ""
        }

        func post(
            url: URL,
            body _: Data?,
            headers _: [String: String]?,
            timeout _: TimeInterval) async throws -> String {
            if let handler {
                let analyzeUrl = try AnalyzeUrl(rawUrl: url.absoluteString)
                return try await handler(analyzeUrl)
            }
            return ""
        }

        func fetch(analyzeUrl: AnalyzeUrl) async throws -> String {
            if let handler {
                return try await handler(analyzeUrl)
            }
            return ""
        }

        func fetchStrResponse(analyzeUrl: AnalyzeUrl) async throws -> StrResponse {
            let body = try await fetch(analyzeUrl: analyzeUrl)
            return StrResponse(
                url: analyzeUrl.url.absoluteString,
                body: body,
                code: 200,
                headers: [:])
        }
    }

    // MARK: - 1. BookSource & Supporting Models Parity

    func testBookSourceAllFieldsAndPartProjection() {
        var source = BookSource(
            bookSourceUrl: "https://novel.android-parity.com",
            bookSourceName: "安卓完全对齐源",
            bookSourceGroup: "网络小说,精品",
            bookSourceType: 0,
            bookUrlPattern: "https://novel.android-parity.com/book/\\d+",
            customOrder: 10,
            enabled: true,
            enabledExplore: true,
            header: "{\"User-Agent\":\"Legado-iOS/Parity\"}")

        source.loginUrl = "https://novel.android-parity.com/login"
        source.loginUi = "[{\"name\":\"用户名\",\"type\":\"text\"}]"
        source.loginCheckJs = "result.indexOf('退出登录') !== -1"
        source.coverDecodeJs = "result + '_decoded'"
        source.respondTime = 120
        source.weight = 100
        source.exploreUrl = "玄幻::https://novel.android-parity.com/xuanhuan"

        // 验证 BaseSource 协议特性
        XCTAssertEqual(source.getKey(), "https://novel.android-parity.com")
        XCTAssertEqual(source.getHeaderMap()["User-Agent"], "Legado-iOS/Parity")

        // 验证 BookSourcePart 轻量投影
        let part = BookSourcePart(from: source)
        XCTAssertEqual(part.bookSourceUrl, "https://novel.android-parity.com")
        XCTAssertEqual(part.bookSourceName, "安卓完全对齐源")
        XCTAssertEqual(part.bookSourceGroup, "网络小说,精品")
        XCTAssertEqual(part.customOrder, 10)
        XCTAssertTrue(part.enabled)
        XCTAssertTrue(part.enabledExplore)
        XCTAssertEqual(part.respondTime, 120)
        XCTAssertEqual(part.weight, 100)

        // 验证组管理辅助方法 (BookSource+Helpers)
        XCTAssertTrue(source.hasGroup("精品"))
        source.addGroup("VIP源")
        XCTAssertTrue(source.hasGroup("VIP源"))
        source.removeGroup("精品")
        XCTAssertFalse(source.hasGroup("精品"))

        // 验证错误注释管理
        source.addErrorComment("网络超时 504")
        XCTAssertTrue(source.bookSourceComment?.contains("网络超时 504") == true)
        source.removeErrorComment()
        XCTAssertFalse(source.bookSourceComment?.contains("网络超时 504") == true)

        // 验证搜索校验词生成
        let checkKeyword = source.getCheckKeyword()
        XCTAssertFalse(checkKeyword.isEmpty)
    }

    func testAuxiliaryModelsParity() throws {
        // 1. FlexChildStyle
        let style = FlexChildStyle(
            layoutFlexGrow: 1.0,
            layoutFlexShrink: 0.0,
            layoutAlignSelf: "center",
            layoutFlexBasisPercent: 0.5)
        XCTAssertEqual(style.layoutFlexGrow, 1.0)
        XCTAssertEqual(style.layoutAlignSelf, "center")

        // 2. RowUi
        let row = RowUi(
            name: "password",
            type: "password",
            action: "login",
            viewName: "密码",
            style: style)
        let rowJson = try JSONEncoder().encode(row)
        let decodedRow = try JSONDecoder().decode(RowUi.self, from: rowJson)
        XCTAssertEqual(decodedRow.name, "password")
        XCTAssertEqual(decodedRow.viewName, "密码")

        // 3. ExploreKind
        let kind = ExploreKind(title: "热门榜", url: "https://novel.com/hot", style: style)
        XCTAssertEqual(kind.title, "热门榜")
        XCTAssertEqual(kind.url, "https://novel.com/hot")

        // 4. CustomUrl
        let custom = CustomUrl(url: "https://novel.com/search,{\"type\":\"post\",\"weight\":5}")
        XCTAssertEqual(custom.getUrl(), "https://novel.com/search")
        XCTAssertEqual(custom.getAttributes()["type"], "post")
        XCTAssertEqual(custom.getAttributes()["weight"], "5")
    }

    // MARK: - 2. BookChapterList Reverse & FormatJS Parity

    func testBookChapterListReverseAndJsFormatting() async throws {
        var source = BookSource(
            bookSourceUrl: "https://toc.example.com",
            bookSourceName: "TOC测试源")
        var tocRule = TocRule()
        // 以 "-" 开头表示倒序章节列表 (对齐 Android BookChapterList.kt:28)
        tocRule.chapterList = "-.chapter-item"
        tocRule.chapterName = "a@text"
        tocRule.chapterUrl = "a@href"
        tocRule.isVip = ".vip@text"
        // formatJs: 章节标题格式化 (对齐 Android BookChapterList.kt:141)
        tocRule.formatJs = "'[第' + index + '节] ' + title"
        source.ruleToc = tocRule

        let book = Book(
            bookUrl: "https://toc.example.com/book/1",
            tocUrl: "https://toc.example.com/book/1/toc",
            origin: "https://toc.example.com",
            originName: "TOC测试源",
            name: "测试书籍",
            author: "测试作者")

        let mockHtml = """
        <html>
        <body>
            <div class="chapter-item"><a href="/ch1.html">第一章 入道</a><span class="vip">false</span></div>
            <div class="chapter-item"><a href="/ch2.html">第二章 筑基</a><span class="vip">false</span></div>
            <div class="chapter-item"><a href="/ch3.html">第三章 金丹</a><span class="vip">true</span></div>
        </body>
        </html>
        """

        let chapters = try await BookChapterList.analyzeChapterList(
            bookSource: source,
            book: book,
            baseUrl: "https://toc.example.com",
            redirectUrl: "https://toc.example.com/book/1/toc",
            body: mockHtml)

        // 原本为 1, 2, 3，由于 "-" 规则，倒序排列为 3, 2, 1
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[0].title, "[第1节] 第三章 金丹")
        XCTAssertEqual(chapters[0].url, "https://toc.example.com/ch3.html")
        XCTAssertTrue(chapters[0].isVip)

        XCTAssertEqual(chapters[1].title, "[第2节] 第二章 筑基")
        XCTAssertEqual(chapters[1].url, "https://toc.example.com/ch2.html")
        XCTAssertFalse(chapters[1].isVip)

        XCTAssertEqual(chapters[2].title, "[第3节] 第一章 入道")
        XCTAssertEqual(chapters[2].url, "https://toc.example.com/ch1.html")
        XCTAssertFalse(chapters[2].isVip)
    }

    // MARK: - 3. BookContent Parsing & Regex Replacement Parity

    func testBookContentParsingAndRegexClean() async throws {
        var source = BookSource(
            bookSourceUrl: "https://content.example.com",
            bookSourceName: "正文测试源")
        var contentRule = ContentRule()
        contentRule.content = "#content@textNodes"
        contentRule.title = "h1@text"
        contentRule.replaceRegex = "##【本章广告：.*】##"
        source.ruleContent = contentRule

        let book = Book(
            bookUrl: "https://content.example.com/b/1",
            origin: "https://content.example.com",
            originName: "正文源",
            name: "凡人修仙",
            author: "忘语")

        let chapter = Chapter(
            bookUrl: book.bookUrl,
            title: "第一章 初始",
            url: "https://content.example.com/b/1/ch1.html",
            index: 0)

        let mockBody = """
        <html>
        <body>
            <h1>第一章 初始 - 极速纯净版</h1>
            <div id="content">
                <p>山间的晨雾尚未散尽，少年已经早早醒来。</p>
                <p>【本章广告：下载APP看更多VIP精彩内容】</p>
                <p>这一日的修行，将改变他一生的命运。</p>
            </div>
        </body>
        </html>
        """

        let result = try await BookContent.analyzeContent(
            bookSource: source,
            book: book,
            chapter: chapter,
            baseUrl: "https://content.example.com",
            redirectUrl: chapter.url,
            body: mockBody)

        XCTAssertTrue(result.contains("山间的晨雾尚未散尽"))
        XCTAssertTrue(result.contains("这一日的修行，将改变他一生的命运"))
        // 验证广告被 replaceRegex 彻底剔除
        XCTAssertFalse(result.contains("本章广告"))
    }

    // MARK: - 4. BookInfo & BookList Parity

    func testBookInfoAndBookListParsing() async throws {
        var source = BookSource(
            bookSourceUrl: "https://novel.test",
            bookSourceName: "信息源")
        var infoRule = BookInfoRule()
        infoRule.name = "h1.title@text"
        infoRule.author = ".author@text"
        infoRule.intro = ".intro@text"
        infoRule.coverUrl = ".cover img@src"
        infoRule.kind = ".tags span@text"
        infoRule.lastChapter = ".latest-chapter@text"
        infoRule.tocUrl = "a.toc-link@href"
        source.ruleBookInfo = infoRule

        var searchRule = SearchRule()
        searchRule.bookList = ".book-item"
        searchRule.name = ".book-name@text"
        searchRule.author = ".book-author@text"
        searchRule.bookUrl = "a.book-link@href"
        source.ruleSearch = searchRule

        let book = Book(
            bookUrl: "https://novel.test/book/100",
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: "",
            author: "")

        let mockDetailHtml = """
        <html><body>
            <h1 class="title">大奉打更人</h1>
            <div class="author">卖报小郎君</div>
            <div class="cover"><img src="/covers/dafeng.jpg" /></div>
            <div class="intro">许七安幽幽醒来，发现自己身处牢狱之中。</div>
            <div class="tags"><span>仙侠</span><span>探案</span></div>
            <div class="latest-chapter">第890章 完结感言</div>
            <a class="toc-link" href="/book/100/catalog.html">查看完整目录</a>
        </body></html>
        """

        // 1. 验证 BookInfo
        let enrichedBook = try await BookInfo.analyzeBookInfo(
            book: book,
            body: mockDetailHtml,
            bookSource: source,
            baseUrl: "https://novel.test",
            redirectUrl: "https://novel.test/book/100")

        XCTAssertEqual(enrichedBook.name, "大奉打更人")
        XCTAssertEqual(enrichedBook.author, "卖报小郎君")
        XCTAssertEqual(enrichedBook.coverUrl, "https://novel.test/covers/dafeng.jpg")
        XCTAssertEqual(enrichedBook.intro, "许七安幽幽醒来，发现自己身处牢狱之中。")
        XCTAssertEqual(enrichedBook.tocUrl, "https://novel.test/book/100/catalog.html")
        XCTAssertEqual(enrichedBook.latestChapterTitle, "第890章 完结感言")

        // 2. 验证 BookList
        let mockSearchHtml = """
        <div class="book-item">
            <span class="book-name">剑来</span>
            <span class="book-author">烽火戏诸侯</span>
            <a class="book-link" href="/book/200">详情</a>
        </div>
        """
        let searchResults = try await BookList.analyzeBookList(
            body: mockSearchHtml,
            bookSource: source,
            rule: searchRule,
            baseUrl: "https://novel.test",
            redirectUrl: "https://novel.test/search",
            isSearch: true)

        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults[0].name, "剑来")
        XCTAssertEqual(searchResults[0].author, "烽火戏诸侯")
        XCTAssertEqual(searchResults[0].bookUrl, "https://novel.test/book/200")
    }

    // MARK: - 5. WebBook End-to-End Facade Parity

    func testWebBookEndToEndFacade() async throws {
        var source = BookSource(
            bookSourceUrl: "https://facade.example.com",
            bookSourceName: "门面测试源",
            searchUrl: "https://facade.example.com/search?kw={{key}}")

        var searchRule = SearchRule()
        searchRule.bookList = ".item"
        searchRule.name = ".title@text"
        searchRule.author = ".author@text"
        searchRule.bookUrl = "a@href"
        source.ruleSearch = searchRule

        var infoRule = BookInfoRule()
        infoRule.name = "h1@text"
        infoRule.intro = ".desc@text"
        infoRule.tocUrl = "a.toc@href"
        source.ruleBookInfo = infoRule

        var tocRule = TocRule()
        tocRule.chapterList = ".ch"
        tocRule.chapterName = "a@text"
        tocRule.chapterUrl = "a@href"
        source.ruleToc = tocRule

        var contentRule = ContentRule()
        contentRule.content = ".text@text"
        source.ruleContent = contentRule

        let mockClient = MockParityHttpClient()
        mockClient.handler = { analyzeUrl in
            let path = analyzeUrl.url.path
            if path.contains("search") || analyzeUrl.url.query?.contains("kw=") == true {
                return "<div class='item'><span class='title'>雪中悍刀行</span><span class='author'>烽火</span><a href='/book/300'></a></div>"
            } else if path.contains("catalog") {
                return "<div class='ch'><a href='/ch1.html'>第1回 小二上酒</a></div>"
            } else if path.contains("ch1.html") {
                return "<div class='text'>北凉参差百万户，其中多少铁衣裹枯骨。</div>"
            } else if path.contains("book/300") {
                return "<h1>雪中悍刀行</h1><p class='desc'>江湖是一张珠帘。</p><a class='toc' href='/catalog.html'></a>"
            }
            return ""
        }

        let webBook = WebBook(httpClient: mockClient)

        // 1. searchBookAwait
        let searchList = try await webBook.searchBookAwait(
            bookSource: source,
            key: "雪中",
            page: 1)
        XCTAssertEqual(searchList.count, 1)
        XCTAssertEqual(searchList[0].name, "雪中悍刀行")

        // 2. getBookInfoAwait
        let targetBook = searchList[0].toBook()
        let detailBook = try await webBook.getBookInfoAwait(
            bookSource: source,
            book: targetBook)
        XCTAssertEqual(detailBook.intro, "江湖是一张珠帘。")

        // 3. getChapterListAwait
        let chapters = try await webBook.getChapterListAwait(
            bookSource: source,
            book: detailBook)
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].title, "第1回 小二上酒")

        // 4. getContentAwait
        let chapter = chapters[0]
        let content = try await webBook.getContentAwait(
            bookSource: source,
            book: detailBook,
            chapter: chapter)
        XCTAssertTrue(content.contains("北凉参差百万户"))
    }

    // MARK: - 6. SourceHelp & SourceVerificationHelp Parity

    func testSourceHelpAndVerificationParity() {
        let s1 = BookSource(bookSourceUrl: "https://s1.com", bookSourceName: "源1", customOrder: 10)
        let s2 = BookSource(bookSourceUrl: "https://s2.com", bookSourceName: "源2", customOrder: 10)
        let s3 = BookSource(bookSourceUrl: "https://s3.com", bookSourceName: "源3", customOrder: 30)

        // 验证序号重排 (adjustSortNumber: 发生序号重复时重排并按 0, 1, 2 分配)
        let adjusted = SourceHelp.adjustSortNumber([s3, s1, s2])
        XCTAssertEqual(adjusted[0].customOrder, 0)
        XCTAssertEqual(adjusted[1].customOrder, 1)
        XCTAssertEqual(adjusted[2].customOrder, 2)

        // 验证 18+ 源识别 (is18Plus)
        let adultSource = BookSource(
            bookSourceUrl: "https://r18.novel.com",
            bookSourceName: "深夜福利小说",
            bookSourceGroup: "18禁,成人")
        XCTAssertTrue(SourceHelp.is18Plus(adultSource))

        let normalSource = BookSource(
            bookSourceUrl: "https://qidian.com",
            bookSourceName: "起点中文网",
            bookSourceGroup: "正版")
        XCTAssertFalse(SourceHelp.is18Plus(normalSource))

        // 验证验证码/人机验证辅助结果存取 (SourceVerificationHelp)
        SourceVerificationHelp.setResult(sourceKey: "https://cloudflare-verify.com", result: "cookie_pass=1")
        let cached = SourceVerificationHelp.getResult(sourceKey: "https://cloudflare-verify.com")
        XCTAssertEqual(cached?.result, "cookie_pass=1")
    }
}
