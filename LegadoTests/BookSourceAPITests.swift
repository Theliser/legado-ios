import Foundation
@testable import Legado
import XCTest

/// 书源全量 API、Cloudflare 403 / 验证码机制与数据层解析核心单元测试
final class BookSourceAPITests: XCTestCase {

    override func setUp() {
        super.setUp()
        CookieStore.shared.clearAll()
        BrowserVerificationManager.shared.setMockHandler(nil)
    }

    override func tearDown() {
        CookieStore.shared.clearAll()
        BrowserVerificationManager.shared.setMockHandler(nil)
        super.tearDown()
    }

    // MARK: - 1. CookieStore 跨会话持久化与对齐测试

    func testCookieStoreSetAndGet() {
        let testUrl = "https://example.com/books"
        CookieStore.shared.setCookie(url: testUrl, cookie: "session_id=abc123456; Path=/; Secure")

        let cookies = CookieStore.shared.getCookie(url: testUrl)
        XCTAssertTrue(cookies.contains("session_id=abc123456"))
    }

    func testCookieStoreMergingAndOverwrite() {
        let testUrl = "https://novel.test.org/api/chapter"
        // 第一次设置两个 cookie
        CookieStore.shared.setCookie(url: testUrl, cookie: "token=first_token; user=alice")
        // 第二次更新 token，保留 user
        CookieStore.shared.setCookie(url: testUrl, cookie: "token=second_token; new_key=hello")

        let cookies = CookieStore.shared.getCookie(url: testUrl)
        XCTAssertTrue(cookies.contains("token=second_token"))
        XCTAssertTrue(cookies.contains("user=alice"))
        XCTAssertTrue(cookies.contains("new_key=hello"))
    }

    func testCookieStoreRemoveAndClearAll() {
        let siteA = "https://site-a.com"
        let siteB = "https://site-b.org"

        CookieStore.shared.setCookie(url: siteA, cookie: "a_key=a_val")
        CookieStore.shared.setCookie(url: siteB, cookie: "b_key=b_val")

        CookieStore.shared.removeCookie(url: siteA)
        XCTAssertEqual(CookieStore.shared.getCookie(url: siteA), "")
        XCTAssertTrue(CookieStore.shared.getCookie(url: siteB).contains("b_key=b_val"))

        CookieStore.shared.clearAll()
        XCTAssertEqual(CookieStore.shared.getCookie(url: siteB), "")
    }

    // MARK: - 2. BrowserVerificationManager (Cloudflare 403 / 挑战) 测试

    func testBrowserVerificationManagerMockHandler() async throws {
        let targetUrl = "https://cf-protected-novel.org/search?key=swift"
        let mockHtml = "<html><body><h1>Search Results Behind CF</h1></body></html>"

        BrowserVerificationManager.shared.setMockHandler { url, title in
            XCTAssertEqual(url, targetUrl)
            XCTAssertEqual(title, "安全验证")
            return BrowserVerificationResult(url: url, body: mockHtml)
        }

        let result = try await BrowserVerificationManager.shared.verify(
            url: targetUrl,
            title: "安全验证")

        XCTAssertEqual(result.url, targetUrl)
        XCTAssertEqual(result.body, mockHtml)

        // 验证 mock handler 执行后，是否自动注入 cf_clearance 到 CookieStore
        let storedCookie = CookieStore.shared.getCookie(url: targetUrl)
        XCTAssertTrue(storedCookie.contains("cf_clearance="))
    }

    func testBrowserVerificationManagerVerifySync() {
        let targetUrl = "https://turnstile.challenge.com/chapter1"
        let expectedBody = "<div>Protected Chapter Content</div>"

        BrowserVerificationManager.shared.setMockHandler { url, _ in
            BrowserVerificationResult(url: url, body: expectedBody)
        }

        let syncResult = BrowserVerificationManager.shared.verifySync(
            url: targetUrl,
            title: "人机验证")

        XCTAssertEqual(syncResult.body, expectedBody)
        XCTAssertEqual(syncResult.url, targetUrl)
    }

    func testBrowserVerificationContinuationFlow() async throws {
        let challengeUrl = "https://challenge.flow.com/page"
        let manager = BrowserVerificationManager.shared

        // 异步等待并在另一个 Task 中模拟用户在 WebView 中点击完成
        let task = Task {
            try await manager.verify(url: challengeUrl, title: "点击验证", sourceOrigin: challengeUrl)
        }

        // 短暂让出执行权，等待 continuation 挂起
        try await Task.sleep(nanoseconds: 50_000_000)

        // 模拟完成验证并同步 cookies
        manager.completeVerification(
            key: challengeUrl,
            resultUrl: challengeUrl,
            html: "<html>Verified Content</html>",
            cookies: ["cf_clearance": "passed_token_999", "cf_bm": "bm_token"])

        let res = try await task.value
        XCTAssertEqual(res.body, "<html>Verified Content</html>")

        let stored = CookieStore.shared.getCookie(url: challengeUrl)
        XCTAssertTrue(stored.contains("cf_clearance=passed_token_999"))
        XCTAssertTrue(stored.contains("cf_bm=bm_token"))
    }

    // MARK: - 3. JSEngine 与 Legado JS Bridge API 测试

    func testJSEngineCookieBridge() {
        let jsEngine = JSEngine()
        let testUrl = "https://js-cookie-test.com"

        // 1. 通过 JS 的 cookie.setCookie / java.setCookie 写入
        let scriptSet = """
        cookie.setCookie('\(testUrl)', 'auth_token=jwt_xyz_888');
        java.setCookie('\(testUrl)', 'theme=dark');
        """
        _ = jsEngine.evaluate(script: scriptSet)

        let readFromSwift = CookieStore.shared.getCookie(url: testUrl)
        XCTAssertTrue(readFromSwift.contains("auth_token=jwt_xyz_888"))
        XCTAssertTrue(readFromSwift.contains("theme=dark"))

        // 2. 通过 JS 的 cookie.getCookie / java.getCookie 读取
        let scriptGet = """
        let c1 = cookie.getCookie('\(testUrl)');
        let c2 = java.getCookie('\(testUrl)');
        c1.indexOf('auth_token') >= 0 && c2.indexOf('theme') >= 0;
        """
        let getResult = jsEngine.evaluate(script: scriptGet)
        XCTAssertEqual(getResult, "true")
    }

    func testJSEngineStartBrowserAwait() {
        let jsEngine = JSEngine()
        let protectedUrl = "https://cf.script.test/verify"
        let mockPage = "<html><head><title>Success</title></head><body>Unlocked Content</body></html>"

        BrowserVerificationManager.shared.setMockHandler { url, _ in
            BrowserVerificationResult(url: url, body: mockPage)
        }

        let script = """
        var res = java.startBrowserAwait('\(protectedUrl)', 'Cloudflare 验证', false);
        res.body();
        """
        let bodyResult = jsEngine.evaluate(script: script)
        XCTAssertEqual(bodyResult, mockPage)

        let scriptUrl = "res.url();"
        let urlResult = jsEngine.evaluate(script: scriptUrl)
        XCTAssertEqual(urlResult, protectedUrl)
    }

    // MARK: - 4. SourceSearchService 结合 AnalyzeRule 数据层集成测试

    func testSearchServiceJsonWithPutAndGet() async throws {
        let mockClient = MockHTTPClient()
        let searchService = SourceSearchService(httpClient: mockClient)

        let searchApiJson = """
        {
            "code": 0,
            "data": {
                "list": [
                    {
                        "id": 1001,
                        "title": "斗罗大陆",
                        "author_name": "唐家三少",
                        "summary": "魂师的世界",
                        "img": "https://img.test.com/1001.jpg",
                        "last_ch": "第336章 神界传说"
                    },
                    {
                        "id": 1002,
                        "title": "吞噬星空",
                        "author_name": "我吃西红柿",
                        "summary": "地球经历灾变",
                        "img": "https://img.test.com/1002.jpg",
                        "last_ch": "最终回 宇宙巅峰"
                    }
                ]
            }
        }
        """

        mockClient.register(matching: "/api/search") { _, _, _ in
            searchApiJson
        }

        let source = BookSource(
            bookSourceUrl: "https://api.booktest.com",
            bookSourceName: "JSON API 书源",
            bookSourceType: 0,
            searchUrl: "https://api.booktest.com/api/search?q={{key}}",
            ruleSearch: RuleSearch(
                bookList: "$.data.list",
                name: "title@put:{bookId: '$.id'}",
                author: "author_name",
                intro: "summary",
                lastChapter: "last_ch",
                bookUrl: "https://api.booktest.com/book/@get:{bookId}",
                coverUrl: "img"))

        let results = try await searchService.search(source: source, keyword: "星空", page: 1)
        XCTAssertEqual(results.count, 2)

        let first = results[0]
        XCTAssertEqual(first.name, "斗罗大陆")
        XCTAssertEqual(first.author, "唐家三少")
        XCTAssertEqual(first.intro, "魂师的世界")
        XCTAssertEqual(first.coverUrl, "https://img.test.com/1001.jpg")
        XCTAssertEqual(first.latestChapterTitle, "第336章 神界传说")
        XCTAssertEqual(first.bookUrl, "https://api.booktest.com/book/1001")

        let second = results[1]
        XCTAssertEqual(second.name, "吞噬星空")
        XCTAssertEqual(second.author, "我吃西红柿")
        XCTAssertEqual(second.bookUrl, "https://api.booktest.com/book/1002")
    }

    func testSearchServiceHtmlWithRegexReplacements() async throws {
        let mockClient = MockHTTPClient()
        let searchService = SourceSearchService(httpClient: mockClient)

        let searchHtml = """
        <!DOCTYPE html>
        <html>
        <body>
            <div class="result-list">
                <div class="book-card">
                    <h3 class="name"><a href="/book/987">【精选】诡秘之主（全本）</a></h3>
                    <p class="author">作者：爱潜水的乌贼</p>
                    <p class="desc">愚者重临大地...</p>
                    <img class="pic" src="/covers/987.jpg" />
                </div>
            </div>
        </body>
        </html>
        """

        mockClient.register(matching: "/search") { _, _, _ in
            searchHtml
        }

        let source = BookSource(
            bookSourceUrl: "https://html.novel.com",
            bookSourceName: "HTML 搜索书源",
            bookSourceType: 0,
            searchUrl: "https://html.novel.com/search?keyword={{key}}",
            ruleSearch: RuleSearch(
                bookList: "div.result-list div.book-card",
                name: "h3.name a@text##【精选】|（全本）##",
                author: "p.author@text##作者：##",
                intro: "p.desc@text",
                bookUrl: "h3.name a@href",
                coverUrl: "img.pic@src"))

        let results = try await searchService.search(source: source, keyword: "诡秘", page: 1)
        XCTAssertEqual(results.count, 1)

        let book = results[0]
        XCTAssertEqual(book.name, "诡秘之主")
        XCTAssertEqual(book.author, "爱潜水的乌贼")
        XCTAssertEqual(book.intro, "愚者重临大地...")
        XCTAssertEqual(book.coverUrl, "https://html.novel.com/covers/987.jpg")
        XCTAssertEqual(book.bookUrl, "https://html.novel.com/book/987")
    }

    // MARK: - 5. SourceDetailAndTocService 结合 AnalyzeRule 数据层集成测试

    func testDetailAndTocServiceDetailParsing() async throws {
        let mockClient = MockHTTPClient()
        let detailService = SourceDetailAndTocService(httpClient: mockClient)

        let detailHtml = """
        <html>
        <head><title>凡人修仙传详情</title></head>
        <body>
            <div id="info">
                <h1>凡人修仙传</h1>
                <p>作者：忘语</p>
                <div class="intro">山村少年韩立，偶然之下加入修仙门派...</div>
                <img id="fm" src="/cover/fr.jpg"/>
                <p class="tag">仙侠修真</p>
            </div>
        </body>
        </html>
        """

        mockClient.register(matching: "/book/123") { _, _, _ in
            detailHtml
        }

        let source = BookSource(
            bookSourceUrl: "https://fanren.com",
            bookSourceName: "凡人书源",
            bookSourceType: 0,
            ruleBookInfo: RuleBookInfo(
                name: "#info h1@text",
                author: "#info p:matches(作者)@text##作者：##",
                intro: "div.intro@text",
                kind: "p.tag@text",
                coverUrl: "img#fm@src"))

        let rawBook = Book(
            bookUrl: "https://fanren.com/book/123",
            origin: "https://fanren.com",
            name: "临时书名",
            author: "")
        let detailBook = try await detailService.fetchBookDetail(book: rawBook, source: source)

        XCTAssertEqual(detailBook.name, "凡人修仙传")
        XCTAssertEqual(detailBook.author, "忘语")
        XCTAssertEqual(detailBook.intro, "山村少年韩立，偶然之下加入修仙门派...")
        XCTAssertEqual(detailBook.coverUrl, "https://fanren.com/cover/fr.jpg")
        XCTAssertEqual(detailBook.kind, "仙侠修真")
    }

    func testDetailAndTocServiceTocParsing() async throws {
        let mockClient = MockHTTPClient()
        let detailService = SourceDetailAndTocService(httpClient: mockClient)

        let tocHtml = """
        <html>
        <body>
            <ul class="chapter-list">
                <li><a href="/ch/1.html">第一章 山边小村</a></li>
                <li><a href="/ch/2.html">第二章 七玄门</a></li>
                <li><a href="/ch/3.html">第三章 墨大夫</a></li>
            </ul>
        </body>
        </html>
        """

        mockClient.register(matching: "/book/123/toc") { _, _, _ in
            tocHtml
        }

        let source = BookSource(
            bookSourceUrl: "https://fanren.com",
            bookSourceName: "凡人书源",
            bookSourceType: 0,
            ruleToc: RuleToc(
                chapterList: "ul.chapter-list li a",
                chapterName: "text",
                chapterUrl: "href"))

        let book = Book(
            bookUrl: "https://fanren.com/book/123/toc",
            origin: "https://fanren.com",
            name: "凡人修仙传",
            author: "忘语")
        let chapters = try await detailService.fetchBookToc(book: book, source: source)

        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[0].title, "第一章 山边小村")
        XCTAssertEqual(chapters[0].url, "https://fanren.com/ch/1.html")
        XCTAssertEqual(chapters[0].index, 0)

        XCTAssertEqual(chapters[1].title, "第二章 七玄门")
        XCTAssertEqual(chapters[1].url, "https://fanren.com/ch/2.html")
        XCTAssertEqual(chapters[1].index, 1)

        XCTAssertEqual(chapters[2].title, "第三章 墨大夫")
        XCTAssertEqual(chapters[2].url, "https://fanren.com/ch/3.html")
        XCTAssertEqual(chapters[2].index, 2)
    }

    // MARK: - 6. ContentParser 章节正文抓取、分页与清洗测试

    func testContentParserSinglePageAndPurify() async throws {
        let mockClient = MockHTTPClient()
        let parser = ContentParser(httpClient: mockClient)

        let contentHtml = """
        <div id="chapter-content">
            <p>第一段：清晨的微风徐徐吹来。</p>
            <p>第二段：韩立缓缓睁开双眼。<br/>体内灵力运转如飞。</p>
            <p>广告：关注微信公众号看更多最新章节！</p>
        </div>
        """

        mockClient.register(matching: "/ch/1.html") { _, _, _ in
            contentHtml
        }

        let source = BookSource(
            bookSourceUrl: "https://fanren.com",
            bookSourceName: "凡人书源",
            bookSourceType: 0,
            ruleContent: RuleContent(
                content: "#chapter-content@html##广告：.*$##",
                sourceRegex: "微风=>凉风"))

        let text = try await parser.fetchAndParseContent(
            chapterUrl: "https://fanren.com/ch/1.html",
            source: source,
            baseUrl: "https://fanren.com")

        XCTAssertTrue(text.contains("第一段：清晨的凉风徐徐吹来。"))
        XCTAssertTrue(text.contains("第二段：韩立缓缓睁开双眼。"))
        XCTAssertTrue(text.contains("体内灵力运转如飞。"))
        XCTAssertFalse(text.contains("广告：关注微信公众号"))
    }

    func testContentParserPaginationNextContentUrl() async throws {
        let mockClient = MockHTTPClient()
        let parser = ContentParser(httpClient: mockClient)

        let page1 = """
        <div class="article">这是第一页的上半部分内容。</div>
        <a id="next_page" href="/ch/100_2.html">下一页</a>
        """

        let page2 = """
        <div class="article">这是第二页的下半部分内容。</div>
        <a id="next_page" href="/ch/101.html">下一章</a>
        """

        mockClient.register(matching: "/ch/100.html") { _, _, _ in page1 }
        mockClient.register(matching: "/ch/100_2.html") { _, _, _ in page2 }

        let source = BookSource(
            bookSourceUrl: "https://pagination.com",
            bookSourceName: "分页书源",
            bookSourceType: 0,
            ruleContent: RuleContent(
                content: "div.article@text",
                nextContentUrl: "a#next_page:matches(下一页)@href"))

        let text = try await parser.fetchAndParseContent(
            chapterUrl: "https://pagination.com/ch/100.html",
            source: source,
            baseUrl: "https://pagination.com")

        XCTAssertTrue(text.contains("这是第一页的上半部分内容。"))
        XCTAssertTrue(text.contains("这是第二页的下半部分内容。"))
    }
}
