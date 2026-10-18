import Foundation
@testable import Legado
import XCTest

final class AnalyzeRuleTests: XCTestCase {

    // MARK: - 1. RuleAnalyzer 分词与分界符测试

    func testBalancedSplitWithNestedBrackets() {
        // 在 [?(@.id > 10 && @.status == 1)] 内部的 && 不应该被切分
        let rule = "$.books[?(@.id > 10 && @.status == 1)].title&&$.magazines.name"
        let parts = RuleAnalyzer.splitRule(rule, "&&")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], "$.books[?(@.id > 10 && @.status == 1)].title")
        XCTAssertEqual(parts[1], "$.magazines.name")
    }

    func testBalancedSplitWithParentheses() {
        let rule = "div.content(a && b)@text&&span.author@text"
        let parts = RuleAnalyzer.splitRule(rule, "&&")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], "div.content(a && b)@text")
        XCTAssertEqual(parts[1], "span.author@text")
    }

    func testCrossMergeSplit() {
        let rule = "$.authors.name%%$.authors.role"
        let parts = RuleAnalyzer.splitRule(rule, "%%")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[0], "$.authors.name")
        XCTAssertEqual(parts[1], "$.authors.role")
    }

    func testChompCodeBalanced() {
        let str = "{name: 'Legado', ver: '3.0'}"
        let chomp = RuleAnalyzer.chompCodeBalanced(str, "{", "}")
        XCTAssertEqual(chomp, "name: 'Legado', ver: '3.0'")
    }

    // MARK: - 2. RuleAnalyzer 模板内联规则测试 (InnerRule)

    func testInnerRuleJsonPathInterpolation() {
        let jsonStr = """
        {"book": {"id": 10086, "title": "斗破苍穹"}}
        """
        let template = "书籍ID为: {$.book.id}, 书名为: {$.book.title}"
        let analyzer = RuleAnalyzer(template)
        let result = analyzer.innerRule("{$.") { path in
            RuleEvaluator.evaluate(json: jsonStr, rule: path)
        }
        XCTAssertEqual(result, "书籍ID为: 10086, 书名为: 斗破苍穹")
    }

    func testInnerRuleJSEvaluation() {
        let template = "计算结果: {{ 100 + 20 * 3 }}"
        let analyzer = RuleAnalyzer(template)
        let jsEngine = JSEngine()
        let result = analyzer.innerRule("{{", "}}") { js in
            jsEngine.evaluate(script: js)
        }
        XCTAssertEqual(result, "计算结果: 160")
    }

    // MARK: - 3. AnalyzeByRegex 正则捕获组与替换测试

    func testRegexGetElementsGroupValues() {
        let text = "Book: 诛仙, Author: 萧鼎; Book: 遮天, Author: 辰东;"
        let pattern = "Book:\\s*([^,]+),\\s*Author:\\s*([^;]+);"
        let elements = AnalyzeByRegex.getElements(res: text, regs: [pattern])

        XCTAssertEqual(elements.count, 2)
        if elements.count >= 2 {
            XCTAssertEqual(elements[0], ["Book: 诛仙, Author: 萧鼎;", "诛仙", "萧鼎"])
            XCTAssertEqual(elements[1], ["Book: 遮天, Author: 辰东;", "遮天", "辰东"])
        }
    }

    func testRegexReplaceWithTemplates() {
        let sourceRule = SourceRule("title##《(.*?)》##【$1】")
        let analyzer = AnalyzeRule()
        let replaced = analyzer.applyRegex(to: "《大奉打更人》", sourceRule: sourceRule)
        XCTAssertEqual(replaced, "【大奉打更人】")
    }

    // MARK: - 4. RuleData 变量传递与隔离测试

    func testRuleDataVariableStorage() {
        let ruleData1 = RuleData()
        let ruleData2 = RuleData()

        _ = ruleData1.putVariable("token", "secret_123")
        XCTAssertEqual(ruleData1.getVariable("token"), "secret_123")
        XCTAssertEqual(ruleData2.getVariable("token"), "")

        ruleData1.putBigVariable("chapter_cache", "huge content")
        XCTAssertEqual(ruleData1.getBigVariable("chapter_cache"), "huge content")
    }

    // MARK: - 5. AnalyzeRule 核心解析器与派发测试

    func testAnalyzeRuleJsonExtraction() {
        let json = """
        {
            "code": 0,
            "data": {
                "name": "诡秘之主",
                "author": "爱潜水的乌贼",
                "intro": "蒸汽与机械的浪潮中..."
            }
        }
        """
        let analyzer = AnalyzeRule()
        analyzer.setContent(json)

        let name = analyzer.getString("$.data.name")
        let author = analyzer.getString("@json:data.author")

        XCTAssertEqual(name, "诡秘之主")
        XCTAssertEqual(author, "爱潜水的乌贼")
    }

    func testAnalyzeRulePutAndGetRules() {
        let json = """
        {
            "bookId": "bk_999",
            "title": "道诡异仙"
        }
        """
        let analyzer = AnalyzeRule()
        analyzer.setContent(json)

        // @put 捕获 bookId 到上下文中，后续规则通过 @get:{id} 或 $id 引用
        let rule = "$.title@put:{id: $.bookId}"
        let title = analyzer.getString(rule)

        XCTAssertEqual(title, "道诡异仙")
        XCTAssertEqual(analyzer.get("id"), "bk_999")

        // 验证后续使用 @get:{id}
        let retrieved = analyzer.getString("@get:{id}")
        XCTAssertEqual(retrieved, "bk_999")
    }

    func testAnalyzeRuleHtmlCssExtraction() {
        let html = """
        <div class="book-box">
            <h1 class="title">宿命之环</h1>
            <span class="author">爱潜水的乌贼</span>
            <div class="desc">
                <p>序章</p>
                <p>第一章 异乡人</p>
            </div>
            <a class="next-page" href="/novel/page/2">下一页</a>
        </div>
        """
        let analyzer = AnalyzeRule()
        analyzer.setContent(html, baseUrl: "https://read.example.com/novel/101")

        let title = analyzer.getString("h1.title@text")
        let author = analyzer.getString(".author@text")
        let absUrl = analyzer.getString("a.next-page@href", isUrl: true)

        XCTAssertEqual(title, "宿命之环")
        XCTAssertEqual(author, "爱潜水的乌贼")
        XCTAssertEqual(absUrl, "https://read.example.com/novel/page/2")
    }

    func testAnalyzeRuleJSEvaluationPipeline() {
        let html = "<div class='score'>9.8</div>"
        let analyzer = AnalyzeRule()
        analyzer.setContent(html)

        // 通过 @js 对提取出的文本进行后处理
        let rule = ".score@text@js: parseFloat(result) * 10"
        let result = analyzer.getString(rule)
        XCTAssertEqual(result, "98")
    }

    func testAnalyzeRuleHtmlUnescape() {
        let escaped = "Hello&nbsp;&amp;&nbsp;&quot;Legado&quot;&lt;&gt;&#39;"
        let unescaped = AnalyzeRule.unescapeHtml(escaped)
        XCTAssertEqual(unescaped, "Hello & \"Legado\"<>'")
    }
}
