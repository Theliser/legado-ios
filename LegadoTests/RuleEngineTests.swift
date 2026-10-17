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
