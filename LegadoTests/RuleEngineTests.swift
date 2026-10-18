import Foundation
@testable import Legado
import XCTest

final class RuleEngineTests: XCTestCase {

    // MARK: - 1. 字符集检测测试

    func testCharsetDetectorUTF8() throws {
        let text = "你好，Legado 阅读！"
        let data = try XCTUnwrap(text.data(using: .utf8))
        let decoded = CharsetDetector.decode(data: data)
        XCTAssertEqual(decoded, text)
    }

    func testCharsetDetectorGBK() throws {
        let text = "诛仙"
        let data = try XCTUnwrap(text.data(using: CharsetDetector.gbkEncoding))
        let decoded = CharsetDetector.decode(data: data)
        XCTAssertEqual(decoded, text)
    }

    // MARK: - 2. JS 引擎与内置 java 拓展测试

    func testJSEngineEvaluation() {
        let engine = JSEngine()
        let result = engine.evaluate(script: "10 + 20 * 2")
        XCTAssertEqual(result, "50")
    }

    func testJSJavaBase64Bridge() {
        let engine = JSEngine()
        let encoded = engine.evaluate(script: "java.base64Encode('Legado')")
        XCTAssertEqual(encoded, "TGVnYWRv")

        let decoded = engine.evaluate(script: "java.base64Decode('TGVnYWRv')")
        XCTAssertEqual(decoded, "Legado")
    }

    func testJSJavaMD5Bridge() {
        let engine = JSEngine()
        let md5 = engine.evaluate(script: "java.md5Encode('123456')")
        XCTAssertEqual(md5, "e10adc3949ba59abbe56e057f20f883e")
    }

    // MARK: - 3. JSONPath 解析测试

    func testJSONPathParser() {
        let json = """
        {
            "status": 1,
            "data": {
                "books": [
                    {"title": "大奉打更人", "author": "卖报小郎君"},
                    {"title": "赤心巡天", "author": "情何以甚"}
                ]
            }
        }
        """

        let titles = JSONPathParser.parse(json: json, path: "$.data.books[*].title")
        XCTAssertEqual(titles, ["大奉打更人", "赤心巡天"])

        let authors = JSONPathParser.parse(json: json, path: "@Json:data.books[*].author")
        XCTAssertEqual(authors, ["卖报小郎君", "情何以甚"])
    }

    // MARK: - 4. CSS 选择器解析测试

    func testCSSSelectorParser() {
        let html = """
        <div class="novel-list">
            <div class="item">
                <a class="book-name" href="/book/1001">大奉打更人</a>
                <span class="author">卖报小郎君</span>
            </div>
            <div class="item">
                <a class="book-name" href="/book/1002">赤心巡天</a>
                <span class="author">情何以甚</span>
            </div>
        </div>
        """

        let titles = CSSSelectorParser.parseElements(html: html, rule: "a.book-name@text")
        XCTAssertEqual(titles, ["大奉打更人", "赤心巡天"])

        let hrefs = CSSSelectorParser.parseElements(html: html, rule: "a.book-name@href", baseUrl: "https://www.example.com")
        XCTAssertEqual(hrefs, ["https://www.example.com/book/1001", "https://www.example.com/book/1002"])
    }

    func testLegadoDOMStepTraversalAndIndexing() {
        let complexHtml = """
        <div id="catalog">
            <ul class="newbox">
                <li><a href="/ch1">第一章</a></li>
                <li><a href="/ch2">第二章</a></li>
                <li><a href="/ch3">第三章</a></li>
            </ul>
        </div>
        <div class="book-info">
            <h3><a href="/author">作者页</a><a href="/book/99">《斗罗大陆》</a></h3>
            <div class="txtnav">
                正文第一段
                <p>内部段落不计入textNodes</p>
                正文第二段
            </div>
            <table>
                <tbody>
                    <tr><th>表头</th></tr>
                    <tr><td>第一行</td></tr>
                    <tr><td>第二行</td></tr>
                </tbody>
            </table>
        </div>
        """

        // 1. 测试 multi-step DOM 步进选择 Elements (class.newbox.0@tag.ul.0@tag.li)
        let liElements = CSSSelectorParser.selectElements(html: complexHtml, rule: "class.newbox.0@tag.ul.0@tag.li")
        XCTAssertEqual(liElements.size(), 3)

        // 2. 测试 步进链 + 索引提取属性 (tag.h3.0@tag.a.1@text)
        let bookName = CSSSelectorParser.parseElements(html: complexHtml, rule: "tag.h3.0@tag.a.1@text")
        XCTAssertEqual(bookName, ["《斗罗大陆》"])

        // 3. 测试 正则清洗 (##《|》)
        let cleanedName = CSSSelectorParser.parseElements(html: complexHtml, rule: "tag.h3.0@tag.a.1@text##《|》")
        XCTAssertEqual(cleanedName, ["斗罗大陆"])

        // 4. 测试 反向切片 (id.catalog.0@tag.ul.0@tag.a[-1:0])
        let reversedTitles = CSSSelectorParser.parseElements(html: complexHtml, rule: "id.catalog.0@tag.ul.0@tag.a[-1:0]@text")
        XCTAssertEqual(reversedTitles, ["第三章", "第二章", "第一章"])

        // 5. 测试 排除索引 (tag.tbody.0@tag.tr!0)
        let trElements = CSSSelectorParser.selectElements(html: complexHtml, rule: "tag.tbody.0@tag.tr!0")
        XCTAssertEqual(trElements.size(), 2)

        // 6. 测试 textNodes 抽取
        let textNodes = CSSSelectorParser.parseElements(html: complexHtml, rule: "class.txtnav.0@textNodes")
        XCTAssertFalse(textNodes.isEmpty)
        XCTAssertTrue(textNodes[0].contains("正文第一段"))
        XCTAssertTrue(textNodes[0].contains("正文第二段"))

        // 7. 测试 @js: 动态处理
        let jsProcessed = CSSSelectorParser.parseElements(
            html: complexHtml,
            rule: "tag.h3.0@tag.a.1@text##《|》@js:'《书名：'+result+'》'")
        XCTAssertEqual(jsProcessed, ["《书名：斗罗大陆》"])
    }

    // MARK: - 5. 书源解析用例测试

    func testParseBookSourceJson() throws {
        let sourceJson = """
        [
            {
                "bookSourceUrl": "https://www.biquge.tv",
                "bookSourceName": "笔趣阁",
                "bookSourceGroup": "优选",
                "bookSourceType": 0,
                "searchUrl": "/search?q={{key}}",
                "ruleSearch": {
                    "bookList": ".novelslist2 li",
                    "name": "a@text",
                    "author": ".s4@text",
                    "bookUrl": "a@href"
                },
                "ruleToc": {
                    "chapterList": "#list dd a",
                    "chapterName": "text",
                    "chapterUrl": "href"
                },
                "ruleContent": {
                    "content": "#content@text"
                }
            }
        ]
        """

        let useCase = ParseBookSourceUseCase()
        let sources = try useCase.parse(json: sourceJson)

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].bookSourceName, "笔趣阁")
        XCTAssertEqual(sources[0].bookSourceUrl, "https://www.biquge.tv")
        XCTAssertEqual(sources[0].ruleSearch?.name, "a@text")
        XCTAssertEqual(sources[0].ruleContent?.content, "#content@text")
    }
}
