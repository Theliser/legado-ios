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
        let report = await debugUseCase.execute(source: source, keyword: "剑神重生")

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
        #expect(report.sampleResult?.name.contains("剑神") == true)
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
                bookUrl: "tag.a.1@href",
                coverUrl: "tag.img.0@src"))

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

    @Test("Test Real Source Crypto and Encoding Methods in JSEngine")
    func realSourceCryptoAndEncodingMethods() {
        let jsEngine = JSEngine()

        // 1. MD5-16
        let md516 = jsEngine.evaluate(script: "java.md5Encode16('123456')")
        #expect(md516 == "49ba59abbe56e057")

        // 2. Digest Hex (SHA-256)
        let sha256 = jsEngine.evaluate(script: "java.digestHex('hello', 'SHA-256')")
        #expect(sha256 == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")

        // 3. HMAC Hex & Base64
        let hmacHex = jsEngine.evaluate(script: "java.HMacHex('hello', 'SHA-256', 'secret_key')")
        let hmacB64 = jsEngine.evaluate(script: "java.HMacBase64('hello', 'SHA-256', 'secret_key')")
        #expect(hmacHex?.count == 64)
        #expect(hmacB64?.isEmpty == false)

        // 4. 对称加解密 (AES/ECB)
        let encrypted = jsEngine.evaluate(
            script: "java.createSymmetricCrypto('AES/ECB/PKCS5Padding', '1234567890123456').encryptBase64('hello world')")
        #expect(encrypted?.isEmpty == false)
        let decrypted = jsEngine.evaluate(
            script: "java.createSymmetricCrypto('AES/ECB/PKCS5Padding', '1234567890123456').decryptStr('\(encrypted!)')")
        #expect(decrypted == "hello world")

        // 5. 中文数字章节名转换 (toNumChapter)
        let title1 = jsEngine.evaluate(script: "java.toNumChapter('第一千二百三十四章 远古太阳神')")
        #expect(title1 == "第1234章 远古太阳神")

        // 6. htmlFormat 与 randomUUID
        let formatted = jsEngine.evaluate(script: "java.htmlFormat('<p>第一段<br>换行</p><p>第二段</p>')")
        #expect(formatted?.contains("第一段") == true)
        let uuid = jsEngine.evaluate(script: "java.randomUUID()")
        #expect(uuid?.contains("-") == true)
    }

    @Test("Test Real World Complex AnalyzeUrl Parsing")
    func realWorldComplexAnalyzeUrlParsing() throws {
        // 1. 和图书: 前置 <js> 校验真人后跟随相对搜索 URL
        let hetuRule = "<js>if(baseUrl == 'https://hetushu.com') { 'passed'; };</js>/search/?keyword={{key}}"
        let hetuUrl = try AnalyzeUrl(
            rawUrl: hetuRule,
            key: "宿命之环",
            baseUrl: "https://hetushu.com")
        #expect(hetuUrl.url.absoluteString == "https://hetushu.com/search/?keyword=%E5%AE%BF%E5%91%BD%E4%B9%8B%E7%8E%AF")

        // 2. 69书吧.com: 误加 <js> 标签包裹的 POST URL
        let shubaRule = "<js>/modules/article/search.php,{'charset':'gbk','body':'searchkey={{key}}&searchtype=all','method':'POST'};result='';result;</js>"
        let shubaUrl = try AnalyzeUrl(
            rawUrl: shubaRule,
            key: "宿命之环",
            baseUrl: "https://www.69shuba.com")
        #expect(shubaUrl.method == "POST")
        #expect(shubaUrl.url.absoluteString.contains("/modules/article/search.php"))
        #expect(shubaUrl.body != nil)

        // 3. 顶点小说: @js: 动态生成带 JSON 请求体的 POST URL
        let ddxsRule = "@js:url=\"https://m.ddxs.com/search.php,{'body':'keyword={{key}}&json=1','method':'POST'}\";result=url;"
        let ddxsUrl = try AnalyzeUrl(
            rawUrl: ddxsRule,
            key: "宿命之环",
            baseUrl: "https://m.ddxs.com")
        #expect(ddxsUrl.method == "POST")
        #expect(ddxsUrl.url.absoluteString == "https://m.ddxs.com/search.php")
        #expect(ddxsUrl.body != nil)
    }

    @Test("Test Real World DOM Step Exclusion Rules (tag.p.!-1 and tr!0)")
    func realWorldDOMStepExclusionRules() {
        // 1. 武林中文网: 排除末尾广告段落 tag.p.!-1@text
        let html1 = """
        <div class="word_read">
            <p>第一段小说正文内容</p>
            <p>第二段小说正文内容</p>
            <p>武林中文网 最新章节！请勿开启浏览器阅读模式</p>
        </div>
        """
        guard let doc1 = try? SwiftSoup.parse(html1) else {
            Issue.record("SwiftSoup failed")
            return
        }
        let pRule = "class.word_read.0@tag.p.!-1@text"
        let pResults = CSSSelectorParser.parse(element: doc1, rule: pRule)
        #expect(pResults.count == 2)
        #expect(pResults[0] == "第一段小说正文内容")
        #expect(pResults[1] == "第二段小说正文内容")

        // 2. 就爱文学: 排除表格表头行 tbody@tr!0
        let html2 = """
        <table id="author">
            <tbody>
                <tr><th>书名</th><th>作者</th></tr>
                <tr><td>宿命之环</td><td>爱潜水的乌贼</td></tr>
                <tr><td>诡秘之主</td><td>爱潜水的乌贼</td></tr>
            </tbody>
        </table>
        """
        guard let doc2 = try? SwiftSoup.parse(html2) else {
            Issue.record("SwiftSoup failed")
            return
        }
        let trRule = "#author@tbody@tr!0@text"
        let trResults = CSSSelectorParser.parse(element: doc2, rule: trRule)
        #expect(trResults.count == 2)
        #expect(trResults[0].contains("宿命之环"))
        #expect(trResults[1].contains("诡秘之主"))
    }

    @Test("Test Case-Insensitive @json: Prefix Rule Handling")
    func caseInsensitiveJsonPrefix() {
        let jsonStr = """
        {
            "code": 1,
            "data": {
                "name": "星之剑士",
                "list": [
                    {"id": "1001", "title": "第一章 序幕"},
                    {"id": "1002", "title": "第二章 出发"}
                ]
            }
        }
        """

        // 1. JSONPathParser.parseArray with @json:
        let listLowercase = JSONPathParser.parseArray(json: jsonStr, path: "@json:$.data.list")
        #expect(listLowercase?.count == 2)

        let listUppercase = JSONPathParser.parseArray(json: jsonStr, path: "@Json:$.data.list")
        #expect(listUppercase?.count == 2)

        // 2. RuleEvaluator.extractField with @json:
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("Failed to deserialize JSON")
            return
        }

        let nameResult = RuleEvaluator.evaluate(dict: dict, rule: "@json:$.data.name")
        #expect(nameResult == "星之剑士")

        // 3. RuleAnalyzer with @json:
        let analyzerResults = RuleAnalyzer().extractList(content: jsonStr, rule: "@json:$.data.name")
        #expect(analyzerResults == ["星之剑士"])
    }

    @Test("Test Real-World Source 1 (话本小说): 发现, 搜索, 书籍, 章节正文 全链路实测")
    func huabenFullLifecycle() async throws {
        let huabenJson = """
        {
          "bookSourceName": "话本小说（优++）",
          "bookSourceUrl": "https://www.ihuaben.com/",
          "bookSourceType": 0,
          "enabled": true,
          "enabledExplore": true,
          "header": "{\\"plantype\\":\\"ANDROID\\",\\"packageid\\":\\"ihuaben\\",\\"content-type\\":\\"application/x-www-form-urlencoded\\"}",
          "searchUrl": "/app/search?indexName=book&keyword={{key}}&page={{page}}&tokenId=NTAyNDUwNTA6MTYyNjcyMzYyMzpjMGU3ODlhNzQ3OTZmYmIy",
          "exploreUrl": "[{\\"title\\":\\"都市言情\\",\\"url\\":\\"/app/lib/listv2?packageId=ihuaben&page={{page}}&pageSize=20&sortType=clickcount_days_7&tagId=0&tokenId=NTAyNDUwNTA6MTYyNjcyMzYyMzpjMGU3ODlhNzQ3OTZmYmIy&keyword=都市言情\\"}]",
          "ruleSearch": {
            "bookList": "$..pageList[*]",
            "name": "$.bookname@put:{bookid:$.bookid}",
            "author": "$.authorname",
            "kind": "$.bookmarks",
            "intro": "$.bookinfo",
            "coverUrl": "http://picapp.ihuaben.com/{{$.bookpic}}",
            "bookUrl": "https://cdncn.ihuaben.com/cdn/chapters/@get:{bookid}/{{Date.parse(new Date())}}"
          },
          "ruleExplore": {
            "bookList": "$..pageList[*]",
            "name": "$.bookname@put:{bookid:$.bookid}",
            "author": "$.authorname",
            "kind": "$.bookmarks",
            "intro": "$.bookinfo",
            "coverUrl": "http://picapp.ihuaben.com/{{$.bookpic}}",
            "bookUrl": "https://cdncn.ihuaben.com/cdn/chapters/@get:{bookid}/{{Date.parse(new Date())}}"
          },
          "ruleToc": {
            "chapterList": "$..chapters[*]",
            "chapterName": "$.title",
            "chapterUrl": "https://cdncn.ihuaben.com/cdn/chapter/{{$.bookId}}/{{$.chapterId}}/{{Date.parse(new Date())}}"
          },
          "ruleContent": {
            "content": "$..content##\\\\[img:(.*?)\\\\]##<img src=\\"http://picapp.ihuaben.com/$1\\" />"
          }
        }
        """

        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: huabenJson)
        #expect(sources.count == 1)
        let source = sources[0]

        // 1. 发现 (Explore) 测试
        let exploreService = SourceExploreService.shared
        let categories = exploreService.parseCategories(source: source)
        #expect(!categories.isEmpty)
        let firstCat = categories[0]
        #expect(firstCat.title == "都市言情")

        let exploreBooks = try await exploreService.fetchExploreBooks(source: source, category: firstCat, page: 1)
        #expect(!exploreBooks.isEmpty)
        #expect(!exploreBooks[0].name.isEmpty)
        #expect(!exploreBooks[0].author.isEmpty)

        // 2. 搜索 (Search) 测试
        let searchService = SourceSearchService.shared
        let searchResults = try await searchService.search(source: source, keyword: "剑")
        #expect(!searchResults.isEmpty)
        let matchedBook = searchResults[0]
        #expect(!matchedBook.name.isEmpty)
        #expect(matchedBook.bookUrl.contains("cdncn.ihuaben.com"))

        // 3. 书籍详情与目录 (Detail & TOC) 测试
        let sampleBook = Book(
            bookUrl: matchedBook.bookUrl,
            origin: source.bookSourceUrl,
            name: matchedBook.name,
            author: matchedBook.author)
        let detailAndTocService = SourceDetailAndTocService.shared
        let chapters = try await detailAndTocService.fetchBookToc(book: sampleBook, source: source)
        #expect(!chapters.isEmpty)
        let firstChapter = chapters[0]
        #expect(!firstChapter.title.isEmpty)
        #expect(firstChapter.url.contains("cdncn.ihuaben.com/cdn/chapter/"))

        // 4. 正文抓取与排版清洗 (Content) 测试
        print("HUABEN DEBUG firstChapter.url = \(firstChapter.url)")
        let contentParser = ContentParser.shared
        let content = try await contentParser.fetchAndParseContent(
            chapterUrl: firstChapter.url,
            source: source,
            baseUrl: source.bookSourceUrl)
        print("HUABEN DEBUG content count = \(content.count), preview = \(content.prefix(100))")
        #expect(!content.isEmpty)
        #expect(content.contains("\u{3000}\u{3000}"))
    }

    @Test("Test Real-World Source 2 (酷我小说): 搜索, 书籍详情, 目录正文 全链路实测")
    func kuwoFullLifecycle() async throws {
        let parser = ParseBookSourceUseCase()
        let sources = try parser.parse(json: kuwoSourceJson)
        #expect(sources.count == 1)
        let source = sources[0]

        // 1. 搜索 (Search)
        let searchService = SourceSearchService.shared
        let searchResults = try await searchService.search(source: source, keyword: "剑神重生")
        #expect(!searchResults.isEmpty)
        let firstResult = searchResults[0]
        #expect(firstResult.name.contains("剑神"))
        #expect(!firstResult.author.isEmpty)

        // 2. 书籍详情 (Book Detail)
        let detailAndTocService = SourceDetailAndTocService.shared
        let sampleBook = Book(
            bookUrl: firstResult.bookUrl,
            origin: source.bookSourceUrl,
            name: firstResult.name,
            author: firstResult.author)
        let updatedBook = try await detailAndTocService.fetchBookDetail(book: sampleBook, source: source)
        print("KUWO DEBUG updatedBook.tocUrl = \(updatedBook.tocUrl)")
        #expect(updatedBook.name.contains("剑神"))
        #expect(!updatedBook.tocUrl.isEmpty)

        // 3. 目录 (TOC)
        let chapters = try await detailAndTocService.fetchBookToc(book: updatedBook, source: source)
        print("KUWO DEBUG chapters count = \(chapters.count)")
        #expect(chapters.count > 100)
        guard let firstChapter = chapters.first else {
            Issue.record("No chapters found for Kuwo book")
            return
        }
        #expect(firstChapter.title.contains("第一章"))

        // 4. 章节正文 (Content)
        let contentParser = ContentParser.shared
        let content = try await contentParser.fetchAndParseContent(
            chapterUrl: firstChapter.url,
            source: source,
            baseUrl: source.bookSourceUrl)
        #expect(content.count > 100)
        #expect(content.contains("\u{3000}\u{3000}"))
    }
}
