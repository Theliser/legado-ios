import Foundation
@testable import Legado
import SwiftSoup
import Testing

@Suite("Real Book Source Import and Debug Suite")
struct RealBookSourceTests {
    /// 真实书源 1: 酷我小说 (来自 aoaostar/legado，无需登录，API JSON 源)
    let kuwoSourceJson = """
    {
      "bookSourceGroup": "API",
      "bookSourceName": "酷我小说",
      "bookSourceType": 0,
      "bookSourceUrl": "http://appi.kuwo.cn",
      "customOrder": 4,
      "enabled": true,
      "enabledCookieJar": true,
      "enabledExplore": false,
      "header": "{\\n\\t\\"Accept\\": \\"*/*\\",\\n\\t\\"Connection\\": \\"Close\\",\\n\\t\\"User-Agent\\": \\"Dalvik/2.1.0 (Linux; U; Android 8.0.0; LND-AL40 Build/HONORLND-AL40)\\"\\n}",
      "lastUpdateTime": 1713846723225,
      "respondTime": 5653,
      "ruleBookInfo": {
        "author": "$.author_name",
        "coverUrl": "$.cover_url",
        "init": "$.data",
        "intro": "$.intro##(^|[。！？]+[”」）】]?)##$1<br>",
        "kind": "{{$.category_name}},{{$.status}},{{$.update_time}}@js:result.replace(/30/,\\"连载\\").replace(/50/,\\"完结\\").replace(/\\\\s..:.*/,\\"\\")",
        "lastChapter": "$.new_chapter_name##正文卷.|正文.|VIP卷.|默认卷.|卷_|VIP章节.|免费章节.|章节目录.|最新章节.|[\\\\(（【].*?[求更票谢乐发订合补加架字修Kk].*?[】）\\\\)]",
        "name": "$.title",
        "tocUrl": "/novels/api/book/{{$.book_id}}/chapters?paging=0",
        "wordCount": "$.all_words"
      },
      "ruleContent": {
        "content": "$.data.content"
      },
      "ruleExplore": {},
      "ruleSearch": {
        "author": "$.author_name",
        "bookList": "$.data",
        "bookUrl": "/novels/api/book/{{$.book_id}}",
        "coverUrl": "$.cover_url",
        "intro": "$.intro",
        "kind": "{{$.category_name}},{{$.status}}@js:result.replace(/30/,\\"连载\\").replace(/50/,\\"完结\\")",
        "name": "$.title",
        "wordCount": "$.all_words"
      },
      "ruleToc": {
        "chapterList": "$.data",
        "chapterName": "$.chapter_title##正文卷.|正文.|VIP卷.|默认卷.|卷_|VIP章节.|免费章节.|章节目录.|最新章节.|[\\\\(（【].*?[求更票谢乐发订合补加架字修Kk].*?[】）\\\\)]",
        "chapterUrl": "/novels/api/book/{{$.book_id}}/chapters/{{$.chapter_id}}",
        "updateTime": "{{$.volume_name}}•{{$.original_words}}字"
      },
      "searchUrl": "/novels/api/book/search?keyword={{key}}&pi={{page}}&ps=30",
      "weight": 50
    }
    """

    @Test("Test Parsing Real Book Source JSON (Kuwo)")
    func parseRealKuwoSource() throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)

        #expect(sources.count == 1)
        let source = sources[0]
        #expect(source.bookSourceName == "酷我小说")
        #expect(source.bookSourceUrl == "http://appi.kuwo.cn")
        #expect(source.searchUrl?.contains("/novels/api/book/search") == true)
        #expect(source.ruleSearch?.bookList == "$.data")
        #expect(source.ruleSearch?.name == "$.title")
        #expect(source.ruleSearch?.author == "$.author_name")
    }

    @Test("Test Real Book Source Debugging Console (Kuwo Search & Rule Execution)")
    func debugRealKuwoSource() async throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)
        #expect(!sources.isEmpty)
        let source = sources[0]

        let debugUseCase = DebugBookSourceUseCase()
        let report = await debugUseCase.execute(source: source, keyword: "斗罗大陆")

        print("--- 酷我书源调试诊断报告 ---")
        print("书源: \(report.sourceName) | 是否通过: \(report.isSuccess) | 耗时: \(report.durationMs)ms")
        for log in report.logs {
            print("[\(log.level.rawValue)] \(log.message)")
        }
        if let sample = report.sampleResult {
            print("抓取样例: 《\(sample.name)》 作者: \(sample.author) | URL: \(sample.bookUrl)")
        }
        print("----------------------------")

        #expect(report.isSuccess == true)
        #expect(report.sampleResult != nil)
        #expect(report.sampleResult?.name.contains("斗罗大陆") == true)
    }

    @Test("Test Real Book Source Debugging Direct Targets (TOC & Content & Streaming)")
    func kuwoDebugDirectTargets() async throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)
        #expect(!sources.isEmpty)
        let source = sources[0]

        let debugUseCase = DebugBookSourceUseCase()

        // 1. 测试示例生成
        let examples = debugUseCase.generateExamples(for: source)
        #expect(!examples.isEmpty)
        #expect(examples.contains { $0.target == .search })

        // 2. 测试直接调试正文页 (Target = .content)
        final class LogCollector: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var logs: [SourceDebugLog] = []
            func append(_ log: SourceDebugLog) {
                lock.lock()
                defer { lock.unlock() }
                logs.append(log)
            }
        }
        let collector = LogCollector()
        let contentReport = await debugUseCase.execute(
            source: source,
            target: .content,
            query: "http://appi.kuwo.cn/novels/api/book/22292070000065702/chapters/95743741677860190",
            onLog: { newLog in
                collector.append(newLog)
            })

        #expect(contentReport.isSuccess == true)
        #expect(!collector.logs.isEmpty)
        #expect(collector.logs.contains { $0.message.contains("正文抓取成功") })
    }

    @Test("Test Parsing XIU2 Yuedu Master Shuyuan List")
    func parseXIU2ShuyuanList() throws {
        let fileUrl = URL(fileURLWithPath: "/tmp/xiu2_shuyuan.json")
        guard let data = try? Data(contentsOf: fileUrl),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return
        }

        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: jsonStr)
        #expect(sources.count >= 20)
        let sourceNames = Set(sources.map(\.bookSourceName))
        #expect(sourceNames.contains("酷我小说"))
        #expect(sourceNames.contains("番茄小说2"))
        #expect(sourceNames.contains("起点中文"))
    }

    @Test("Test AnalyzeUrl with @js:, calculations and single-quote options")
    func analyzeUrlFeatures() throws {
        let raw1 = "/modules/article/search.php,{'charset':'gbk','body':'searchkey={{key}}&searchtype=all','method':'POST'}"
        let parsed1 = try AnalyzeUrl(
            rawUrl: raw1,
            key: "剑来",
            page: 1,
            baseUrl: "https://www.69shuba.com")
        #expect(parsed1.method == "POST")
        #expect(parsed1.url.absoluteString == "https://www.69shuba.com/modules/article/search.php")
        #expect(parsed1.body != nil)

        let raw2 = "@js:url=\"https://api.example.com/search?q={{key}}&offset={{(page-1)*50}}\""
        let parsed2 = try AnalyzeUrl(
            rawUrl: raw2,
            key: "宿命",
            page: 3,
            baseUrl: "https://api.example.com")
        #expect(parsed2.url.absoluteString.contains("offset=100"))
        #expect(parsed2.url.absoluteString.contains("q=%E5%AE%BF%E5%91%BD"))
    }

    @Test("Test JSEngine HexDecode, Put/Get and Java Bridge")
    func jSEngineAdvancedBridges() {
        let engine = JSEngine()
        let hexScript = "java.hexDecodeToString('68656c6c6f')"
        let decoded = engine.evaluate(script: hexScript)
        #expect(decoded == "hello")

        let putGetScript = """
        java.put('myKey', 'myVal');
        java.getString('myKey');
        """
        let val = engine.evaluate(script: putGetScript)
        #expect(val == "myVal")
    }

    @Test("Test Parsing and Validating shidahuilang good.json Book Source Database")
    func parseGoodShuyuanDatabase() throws {
        let fileUrl = URL(fileURLWithPath: "/tmp/good_shuyuan.json")
        guard let data = try? Data(contentsOf: fileUrl),
              let jsonStr = String(data: data, encoding: .utf8) else {
            return
        }

        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: jsonStr)
        #expect(sources.count > 1000)

        // 验证大量源具备 Legado DOM 步进规则
        let domRuleSources = sources.filter { s in
            let bl = s.ruleSearch?.bookList ?? ""
            return bl.contains("@") || bl.contains("tag.") || bl.contains("class.")
        }
        #expect(domRuleSources.count > 500)
    }

    @Test("Test Real-World 69Shuba Search and TOC HTML Extraction with Step Traversal")
    func realWorld69ShubaExtraction() async throws {
        let searchHtml = """
        <div class="newbox">
            <ul>
                <li>
                    <h3><a href="/author/1">忘语</a><a href="/book/101.html">凡人修仙传</a></h3>
                    <p class="author"><span>作者：</span><span>忘语</span></p>
                    <a href="/book/101.html"><img src="/cover/101.jpg" alt="凡人修仙传"/></a>
                    <div class="intro">山村少年韩立出生贫寒...</div>
                </li>
                <li>
                    <h3><a href="/author/2">我吃西红柿</a><a href="/book/102.html">吞噬星空</a></h3>
                    <p class="author"><span>作者：</span><span>我吃西红柿</span></p>
                    <a href="/book/102.html"><img src="/cover/102.jpg" alt="吞噬星空"/></a>
                    <div class="intro">星空之变，罗峰崛起...</div>
                </li>
            </ul>
        </div>
        """

        let source = BookSource(
            bookSourceUrl: "https://www.69shuba.com",
            bookSourceName: "69书吧",
            searchUrl: "/modules/article/search.php,{'method':'POST','body':'searchkey={{key}}'}",
            ruleSearch: RuleSearch(
                bookList: "class.newbox.0@tag.ul.0@tag.li",
                name: "tag.h3.0@tag.a.1@text",
                author: "tag.p.0@tag.span.1@text",
                intro: "class.intro@text",
                coverUrl: "tag.img.0@src",
                bookUrl: "tag.a.1@href"))

        final class Mock69Client: HTTPClientProtocol, @unchecked Sendable {
            let html: String
            init(html: String) {
                self.html = html
            }

            func get(
                url _: URL,
                headers _: [String: String]?,
                timeout _: TimeInterval) async throws -> String {
                html
            }

            func post(
                url _: URL,
                body _: Data?,
                headers _: [String: String]?,
                timeout _: TimeInterval) async throws -> String {
                html
            }
        }

        let searchService = SourceSearchService(httpClient: Mock69Client(html: searchHtml))
        let results = try await searchService.search(source: source, keyword: "修仙")

        #expect(results.count == 2)
        #expect(results[0].name == "凡人修仙传")
        #expect(results[0].author == "忘语")
        #expect(results[0].bookUrl == "https://www.69shuba.com/book/101.html")
        #expect(results[1].name == "吞噬星空")
        #expect(results[1].author == "我吃西红柿")

        // 验证目录反向切片抓取
        let tocHtml = """
        <div id="catalog">
            <ul>
                <li><a href="/read/101_3.html">第三章 拜入七玄门</a></li>
                <li><a href="/read/101_2.html">第二章 离乡远行</a></li>
                <li><a href="/read/101_1.html">第一章 山村少年</a></li>
            </ul>
        </div>
        """
        let tocSource = BookSource(
            bookSourceUrl: "https://www.69shuba.com",
            bookSourceName: "69书吧",
            ruleToc: RuleToc(
                chapterList: "id.catalog.0@tag.ul.0@tag.a[-1:0]",
                chapterName: "text",
                chapterUrl: "@href"))

        let tocService = SourceDetailAndTocService(httpClient: Mock69Client(html: tocHtml))
        let book = Book(
            bookUrl: "https://www.69shuba.com/book/101.html",
            tocUrl: "https://www.69shuba.com/book/101.html",
            name: "凡人修仙传",
            author: "忘语")
        let chapters = try await tocService.fetchBookToc(book: book, source: tocSource)

        #expect(chapters.count == 3)
        // 验证 [-1:0] 切片成功反转为首章在先
        #expect(chapters[0].title == "第一章 山村少年")
        #expect(chapters[1].title == "第二章 离乡远行")
        #expect(chapters[2].title == "第三章 拜入七玄门")
    }

    @Test("Test Parsing Eryuewuxue Real Book Sources Database (37 Sources)")
    func parseEryuewuxueDatabase() throws {
        let filePath = "/tmp/eryuewuxue_all.json"
        guard FileManager.default.fileExists(atPath: filePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: json)

        #expect(sources.count == 37)
        let novelCount = sources.filter { ($0.bookSourceType ?? 0) == 0 }.count
        let audioCount = sources.filter { ($0.bookSourceType ?? 0) == 1 }.count
        let comicCount = sources.filter { ($0.bookSourceType ?? 0) == 2 }.count
        let videoCount = sources.filter { ($0.bookSourceType ?? 0) == 4 }.count

        #expect(novelCount >= 20)
        #expect(audioCount >= 2)
        #expect(comicCount >= 4)
        #expect(videoCount >= 4)
    }

    @Test("Test Bililightnovel Chinese Conversion and JS DOM Methods")
    func bililightnovelAndChineseConversion() {
        let jsEngine = JSEngine()

        // 1. 验证 java.t2s 与全局 t2s (繁体转简体)
        let s1 = jsEngine.evaluate(script: "java.t2s('嗶哩輕小說線上看')")
        #expect(s1 == "哔哩轻小说线上看")

        // 2. 验证 java.s2t 与全局 s2t (简体转繁体)
        let s2 = jsEngine.evaluate(script: "java.s2t('斗罗大陆')")
        #expect(s2 == "鬥羅大陸")

        // 3. 验证 java.setContent 与 java.getString
        let html = "<div class='novel-title'><a href='/novel/123.html'>春物第三季</a></div>"
        let s3 = jsEngine.evaluate(
            script: """
            java.setContent(src);
            var title = java.getString("class.novel-title@tag.a@text");
            var link = java.getString("class.novel-title@tag.a@href");
            title + "|" + link;
            """,
            bindings: ["src": html, "baseUrl": "https://www.linovelib.com"])
        #expect(s3 == "春物第三季|https://www.linovelib.com/novel/123.html")
    }

    @Test("Test Real World XPath Rule Conversion")
    func realWorldXPathConversion() {
        let xpath1 = "//div[@class='list-group']/div[@class='list-group-item']"
        let css1 = DOMStepEvaluator.convertXPathToCSSIfNeeded(xpath1)
        #expect(css1 == "div.list-group div.list-group-item")

        let xpath2 = "//div[@id='chapter_content']/text()"
        let css2 = DOMStepEvaluator.convertXPathToCSSIfNeeded(xpath2)
        #expect(css2 == "div#chapter_content@text")

        let xpath3 = "//ul[@class='catalog']/li/a/@href"
        let css3 = DOMStepEvaluator.convertXPathToCSSIfNeeded(xpath3)
        #expect(css3 == "ul.catalog li a@href")
    }

    @Test("Test Prefix JS Rule Execution and Rule Branching with Logical OR")
    func prefixJsAndRuleBranching() {
        // 1. 验证前置 <js> 转换数据后再执行 follow-up 提取
        let rawHtml = "<ul class='data'><li>item 1</li><li>item 2</li></ul>"
        let rule = "<js>result.replace('item 1', 'first item')</js>tag.li@text"
        guard let doc = try? SwiftSoup.parse(rawHtml) else {
            Issue.record("SwiftSoup failed")
            return
        }
        let parsed = CSSSelectorParser.parse(element: doc, rule: rule)
        #expect(parsed.contains("first item"))
        #expect(parsed.contains("item 2"))

        // 2. 验证规则中带有 @js: 且 JS 脚本内部包含 || 逻辑时不被截断
        let testHtml = "<h1></h1><h2>副标题内容</h2>"
        guard let doc2 = try? SwiftSoup.parse(testHtml) else {
            Issue.record("SwiftSoup failed")
            return
        }
        let branchRule = "tag.h1@text || tag.h2@text @js: if (result == '' || result == null) { '兜底' } else { result + '_已处理' }"
        let branchParsed = CSSSelectorParser.parse(element: doc2, rule: branchRule)
        #expect(branchParsed.first == "副标题内容_已处理")
    }
}
