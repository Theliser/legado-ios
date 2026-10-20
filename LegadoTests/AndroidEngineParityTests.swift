import Foundation
@testable import Legado
import XCTest

final class AndroidEngineParityTests: XCTestCase {

    // MARK: - 1. Dynamic Header Rules & User-Agent Normalization

    func testDynamicHeaderJsonEvaluation() {
        let dynamicJsHeader = "@js:JSON.stringify({'User-Agent': 'Legado-Dynamic/2.0', 'X-Token': 'abc123'})"
        let parsed = AnalyzeUrl.parseHeaderJson(dynamicJsHeader, baseUrl: "https://api.example.com")
        XCTAssertEqual(parsed["User-Agent"], "Legado-Dynamic/2.0")
        XCTAssertEqual(parsed["X-Token"], "abc123")

        let tagJsHeader = "<js>JSON.stringify({'user-agent': 'TagUA/1.0'})</js>"
        let parsedTag = AnalyzeUrl.parseHeaderJson(tagJsHeader, baseUrl: "https://api.example.com")
        XCTAssertEqual(parsedTag["user-agent"], "TagUA/1.0")
    }

    func testHeaderNormalizationCaseInsensitive() {
        var baseHeaders = ["user-agent": "Default/1.0", "Accept": "text/html"]
        let customHeaders = ["User-Agent": "Custom/2.0", "Authorization": "Bearer xyz"]
        AnalyzeUrl.mergeHeaders(customHeaders, into: &baseHeaders)

        XCTAssertEqual(baseHeaders["User-Agent"], "Custom/2.0")
        XCTAssertNil(baseHeaders["user-agent"])
        XCTAssertEqual(baseHeaders["Accept"], "text/html")
        XCTAssertEqual(baseHeaders["Authorization"], "Bearer xyz")
    }

    func testBookSourceGetHeaderMap() {
        var source = BookSource(
            bookSourceUrl: "https://novel.example.com",
            bookSourceName: "测试源")
        source.header = "{\"User-Agent\": \"SourceUA/3.0\", \"Referer\": \"https://novel.example.com\"}"

        let map = source.getHeaderMap()
        XCTAssertEqual(map["User-Agent"], "SourceUA/3.0")
        XCTAssertEqual(map["Referer"], "https://novel.example.com")
    }

    // MARK: - 2. AnalyzeUrl Options & BodyJS Parsing

    func testAnalyzeUrlFlatHeadersAndOptions() throws {
        let raw = "https://api.example.com/books,{\"method\":\"POST\",\"body\":\"id=100\",\"User-Agent\":\"App/1.0\",\"bodyJs\":\"result + '_modified'\"}"
        let parsed = try AnalyzeUrl(rawUrl: raw, baseUrl: "https://api.example.com")

        XCTAssertEqual(parsed.method, "POST")
        XCTAssertEqual(parsed.headers["User-Agent"], "App/1.0")
        XCTAssertEqual(parsed.bodyJs, "result + '_modified'")
    }

    func testAnalyzeUrlJsOptionUrlModification() throws {
        let raw = "https://api.example.com/search,{\"js\":\"result + '?page=2'\"}"
        let parsed = try AnalyzeUrl(rawUrl: raw, baseUrl: "https://api.example.com")
        XCTAssertEqual(parsed.url.absoluteString, "https://api.example.com/search?page=2")
    }

    // MARK: - 3. JS Engine Source & Variable Bindings

    func testJSEngineSourceAndVariablesBinding() {
        let engine = JSEngine()
        var source = BookSource(
            bookSourceUrl: "https://test.com",
            bookSourceName: "测试源名")
        source.header = "{\"User-Agent\":\"EngineUA\"}"

        let script = """
        (function() {
            source.setVariable('token', 'secret123');
            var v = source.getVariable('token');
            var key = source.getKey();
            var name = source.bookSourceName;
            return key + '|' + name + '|' + v;
        })()
        """
        let res = engine.evaluate(script: script, bindings: [
            "source": source,
            "baseUrl": "https://test.com",
        ])
        XCTAssertEqual(res, "https://test.com|测试源名|secret123")
    }

    // MARK: - 4. JS Engine Android StrResponse Emulation

    func testJSStrResponsePolymorphism() {
        let engine = JSEngine()
        let resp = SyncHTTPResponse(
            body: "{\"status\": \"ok\", \"count\": 42}",
            headers: ["Content-Type": "application/json", "Set-Cookie": "uid=888"],
            cookies: ["uid": "888"],
            data: nil,
            statusCode: 200,
            url: "https://api.example.com/data")
        let wrapped = engine.wrapResponse(resp)
        engine.context.setObject(wrapped, forKeyedSubscript: "res" as NSString)

        // 验证 res.body 兼具属性与方法特性
        let testScript = """
        (function() {
            var bodyProperty = "" + res.body;
            var bodyCall = res.body();
            var codeProp = "" + res.code;
            var codeCall = res.code();
            var isOkProp = "" + res.isSuccessful;
            var isOkCall = res.isSuccessful();
            var cookie = res.cookies['uid'];
            return [bodyProperty == bodyCall, codeProp, codeCall, isOkProp, isOkCall, cookie].join(';');
        })()
        """
        let evalResult = engine.evaluate(script: testScript)
        XCTAssertEqual(evalResult, "true;200;200;true;true;888")
    }

    // MARK: - 5. Android JsExtensions Utilities

    func testAndroidJsExtensions() {
        let engine = JSEngine()

        // 1. encodeURI GBK
        let gbkResult = engine.evaluate(script: "java.encodeURI('测试', 'gbk')")
        XCTAssertEqual(gbkResult, "%B2%E2%CA%D4")

        // 2. htmlFormat
        let htmlResult = engine.evaluate(script: "java.htmlFormat('<p>第一段<br/>第二段</p>')")
        XCTAssertTrue(htmlResult?.contains("第一段\n第二段") == true)

        // 3. timeFormat & timeFormatUTC
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        let expectedLocal = formatter.string(from: Date(timeIntervalSince1970: 1_700_000_000))
        let timeResult = engine.evaluate(script: "java.timeFormat(1700000000, 'yyyy-MM-dd')")
        XCTAssertEqual(timeResult, expectedLocal)

        // 验证 UTC 与时区偏移计算（+8 时区固定产出 2023-11-15）
        let utcResult = engine.evaluate(script: "java.timeFormatUTC(1700000000 * 1000, 'yyyy-MM-dd', 8 * 3600 * 1000)")
        XCTAssertEqual(utcResult, "2023-11-15")

        // 4. randomUUID & androidId
        let uuidResult = engine.evaluate(script: "java.randomUUID()")
        XCTAssertEqual(uuidResult?.count, 36)

        let androidIdResult = engine.evaluate(script: "java.androidId()")
        XCTAssertTrue(androidIdResult?.hasPrefix("a16") == true)

        // 5. toURL
        let toUrlScript = """
        (function() {
            var u = java.toURL('chapter1.html', 'https://example.com/book/index.html');
            return u.url;
        })()
        """
        let urlResult = engine.evaluate(script: toUrlScript)
        XCTAssertEqual(urlResult, "https://example.com/book/chapter1.html")
    }

    // MARK: - 6. Ajax & Connect URL Option Resolution in JS

    func testAjaxAndConnectOptionResolution() {
        let engine = JSEngine()
        var source = BookSource(
            bookSourceUrl: "https://api.example.com",
            bookSourceName: "测试Ajax")
        source.header = "{\"User-Agent\":\"ParityUA/1.0\"}"

        let testScript = """
        (function() {
            var url1 = 'detail.html,{"headers":{"X-Custom":"Val1"}}';
            var parsed = java.toURL(url1, 'https://api.example.com/books/');
            return parsed.url;
        })()
        """
        let res = engine.evaluate(script: testScript, bindings: ["source": source])
        XCTAssertEqual(res, "https://api.example.com/books/detail.html")
    }

    // MARK: - 7. Page List Pattern (<1,2,3> and <,index_2,index_3>)

    func testReplacePageListPattern() {
        let pattern1 = "https://example.com/category/<1,2,3>"
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern1, page: 1), "https://example.com/category/1")
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern1, page: 2), "https://example.com/category/2")
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern1, page: 3), "https://example.com/category/3")
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern1, page: 10), "https://example.com/category/3")

        let pattern2 = "https://example.com/list/<,index_2.html,index_3.html>"
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern2, page: 1), "https://example.com/list/")
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern2, page: 2), "https://example.com/list/index_2.html")
        XCTAssertEqual(AnalyzeUrl.replacePageListPattern(url: pattern2, page: 3), "https://example.com/list/index_3.html")
    }

    // MARK: - 8. CacheManager & cache JS Bridge

    func testCacheManagerAndJSBridge() {
        let engine = JSEngine()
        let script = """
        (function() {
            cache.put('test_k1', 'val_100');
            cache.putMemory('test_mem', 'mem_val');
            var k1 = cache.get('test_k1');
            var mem = cache.getFromMemory('test_mem');
            cache.delete('test_k1');
            var k1_after = cache.get('test_k1') || 'deleted';
            return k1 + '_' + mem + '_' + k1_after;
        })()
        """
        let res = engine.evaluate(script: script)
        XCTAssertEqual(res, "val_100_mem_val_deleted")
    }

    // MARK: - 9. Cookie Full API JS Bridge

    func testCookieFullJSBridge() {
        let engine = JSEngine()
        let script = """
        (function() {
            cookie.setCookie('https://api.cookie-test.com', 'token=abc; role=admin');
            var token = cookie.getKey('https://api.cookie-test.com', 'token');
            cookie.replaceCookie('https://api.cookie-test.com', 'role=super; theme=dark');
            var role = cookie.getKey('https://api.cookie-test.com', 'role');
            var theme = cookie.getKey('https://api.cookie-test.com', 'theme');
            return token + '_' + role + '_' + theme;
        })()
        """
        let res = engine.evaluate(script: script)
        XCTAssertEqual(res, "abc_super_dark")
    }

    // MARK: - 10. Chapter & Contextual JS Bindings

    func testChapterAndContextualJSBindings() {
        let engine = JSEngine()
        let bindings: [String: Any] = [
            "title": "第十章 悟剑",
            "chapterUrl": "https://novel.com/ch10.html",
            "chapterIndex": 10,
            "src": "<html><body>正文内容</body></html>",
            "nextChapterUrl": "https://novel.com/ch11.html",
            "fromBookInfo": true,
        ]
        let script = """
        (function() {
            chapter.setVariable('custom_key', 'custom_val');
            var v = chapter.getVariable('custom_key');
            return chapter.title + '_' + chapter.index + '_' + title + '_' + nextChapterUrl + '_' + v;
        })()
        """
        let res = engine.evaluate(script: script, bindings: bindings)
        XCTAssertEqual(res, "第十章 悟剑_10_第十章 悟剑_https://novel.com/ch11.html_custom_val")
    }

    // MARK: - 11. Regex replaceFirst Syntax (###) & JS Regex Replace

    func testRegexReplaceFirstSyntax() {
        let text = "apple apple apple"
        let replaceAllRule = "##apple##orange"
        let replaceFirstRule = "##apple##orange###"

        let resAll = RuleAnalyzer.applyRegexReplace(text: text, regexRule: replaceAllRule)
        let resFirst = RuleAnalyzer.applyRegexReplace(text: text, regexRule: replaceFirstRule)

        XCTAssertEqual(resAll, "orange orange orange")
        XCTAssertEqual(resFirst, "orange")

        // 验证 Android Legado 正则提取特性 (如抽取 URL 中间书号)
        let urlText = "https://novel.example.com/book/98765/index.html"
        let extractRule = "##book/(\\d+)##$1###"
        let resExtract = RuleAnalyzer.applyRegexReplace(text: urlText, regexRule: extractRule)
        XCTAssertEqual(resExtract, "98765")
    }

    func testRegexReplaceWithJavaScript() {
        let text = "hello world"
        let jsRule = "@js:result.toUpperCase()"
        let res = RuleAnalyzer.applyRegexReplace(text: text, regexRule: jsRule)
        XCTAssertEqual(res, "HELLO WORLD")
    }

    // MARK: - 12. AnalyzeUrl GBK Query Encoding

    func testAnalyzeUrlGBKQueryEncoding() throws {
        let raw = "https://biquge.com/search?keyword=剑来,{\"charset\":\"gbk\"}"
        let parsed = try AnalyzeUrl(rawUrl: raw)
        XCTAssertTrue(parsed.url.absoluteString.contains("keyword=%BD%A3%C0%B4"))
    }
}
