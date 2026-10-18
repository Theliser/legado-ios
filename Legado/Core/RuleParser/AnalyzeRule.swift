import Foundation
import SwiftSoup

/// 统一规则调度中枢引擎 (对齐 Android Legado AnalyzeRule.kt)
///
/// 核心职责：
/// 1. 负责书源全部规则链的切分、Mode 模式判定 (Json / XPath / JSoup / Regex / JS / WebJs)；
/// 2. 管理变量存储与作用域体系 (Chapter -> Book -> RuleData -> Source 四级优先级查找)；
/// 3. 执行动态变量插值与求值：`@put:{...}`、`@get:{...}`、`{{js/rule}}`、`$1`~$9 捕获组回引；
/// 4. 提供统一提取入口：`getString`、`getStringList`、`getElements`、`getElement`；
/// 5. 执行 `evalJS` 绑定上下文对象 (`java`、`source`、`book`、`chapter`、`result`、`baseUrl`、`title`、`src` 等)。
public final class AnalyzeRule: @unchecked Sendable {
    public enum Mode: String, Sendable {
        case xpath
        case json
        case `default`
        case jsRule = "js"
        case regex
        case webJs
    }

    private let lock = NSLock()
    private var ruleData: RuleDataInterface?
    private var book: Book?
    private var source: BookSource?
    private var chapter: Chapter?
    private var nextChapterUrl: String?
    private var variableMap: [String: String] = [:]
    var content: Any?
    var baseUrl: String?
    private var redirectUrl: URL?
    private var isJSON = false
    private var isRegex = false
    private let jsEngine = JSEngine()

    public init(
        ruleData: RuleDataInterface? = nil,
        book: Book? = nil,
        source: BookSource? = nil,
        chapter: Chapter? = nil,
        baseUrl: String? = nil) {
        self.ruleData = ruleData
        self.book = book
        self.source = source
        self.chapter = chapter
        self.baseUrl = baseUrl
    }

    @discardableResult
    public func setBook(_ book: Book?) -> Self {
        self.book = book
        return self
    }

    @discardableResult
    public func setContent(_ content: Any?, baseUrl: String? = nil) -> AnalyzeRule {
        guard let content else { return self }
        self.content = content
        if let str = content as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            self.isJSON = trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
        } else if content is [String: Any] || content is [[String: Any]] {
            self.isJSON = true
        } else {
            self.isJSON = false
        }
        if let baseUrl {
            self.baseUrl = baseUrl
        }
        return self
    }

    @discardableResult
    public func setBaseUrl(_ baseUrl: String?) -> AnalyzeRule {
        if let baseUrl {
            self.baseUrl = baseUrl
        }
        return self
    }

    @discardableResult
    public func setRedirectUrl(_ urlStr: String) -> URL? {
        if let url = URL(string: urlStr) {
            self.redirectUrl = url
            return url
        }
        return nil
    }

    @discardableResult
    public func setChapter(_ chapter: Chapter?) -> AnalyzeRule {
        self.chapter = chapter
        return self
    }

    @discardableResult
    public func setRuleData(_ ruleData: RuleDataInterface?) -> AnalyzeRule {
        self.ruleData = ruleData
        return self
    }

    @discardableResult
    public func setNextChapterUrl(_ url: String?) -> AnalyzeRule {
        self.nextChapterUrl = url
        return self
    }

    // MARK: - 变量存取 (四级作用域：chapter -> ruleData -> source)

    @discardableResult
    public func put(_ key: String, _ value: String) -> String {
        variableMap[key] = value
        _ = ruleData?.putVariable(key, value)
        RuleEvaluator.putVariable(key, value: value)
        return value
    }

    public func get(_ key: String) -> String {
        switch key {
        case "bookName":
            if let book {
                return book.name
            }

        case "title":
            if let activeChapter = chapter {
                return activeChapter.title
            }

        default:
            break
        }

        if let val = variableMap[key], !val.isEmpty {
            return val
        }
        if let val = ruleData?.getVariable(key), !val.isEmpty {
            return val
        }
        return RuleEvaluator.getVariable(key) ?? ""
    }

    // MARK: - JS 脚本求值

    public func evalJS(_ jsStr: String, result: Any? = nil) -> Any? {
        var bindings: [String: Any] = [
            "result": result ?? "",
            "baseUrl": baseUrl ?? "",
            "bookSourceUrl": source?.bookSourceUrl ?? "",
            "bookSourceName": source?.bookSourceName ?? "",
            "loginUrl": source?.loginUrl ?? "",
            "title": chapter?.title ?? "",
            "nextChapterUrl": nextChapterUrl ?? "",
        ]
        if let contentStr = content as? String {
            bindings["src"] = contentStr
        }
        if let source {
            bindings["source"] = [
                "bookSourceUrl": source.bookSourceUrl,
                "bookSourceName": source.bookSourceName,
                "loginUrl": source.loginUrl ?? "",
            ]
        }

        return jsEngine.evaluate(script: jsStr, bindings: bindings)
    }

    // MARK: - 规则切分

    public func splitSourceRule(_ ruleStr: String?, allInOne: Bool = false) -> [SourceRule] {
        guard let ruleStr, !ruleStr.isEmpty else { return [] }
        var ruleList: [SourceRule] = []
        var detectedMode: Mode = .default
        var start = 0
        let trimmed = ruleStr.trimmingCharacters(in: .whitespacesAndNewlines)

        if allInOne, trimmed.hasPrefix(":") {
            detectedMode = .regex
            isRegex = true
            start = 1
        } else if isRegex {
            detectedMode = .regex
        }

        guard let jsRegex = try? NSRegularExpression(
            pattern: #"(?:<js>([\s\S]*?)</js>)|(?:@js:([\s\S]*))"#,
            options: []) else {
            return [SourceRule(ruleStr: trimmed, mode: detectedMode, isJSON: isJSON)]
        }

        let nsStr = trimmed as NSString
        let fullRange = NSRange(location: 0, length: nsStr.length)
        let matches = jsRegex.matches(in: trimmed, options: [], range: fullRange)

        if matches.isEmpty {
            return [SourceRule(ruleStr: trimmed, mode: detectedMode, isJSON: isJSON)]
        }

        for singleMatch in matches {
            if singleMatch.range.location > start {
                let sub = nsStr.substring(with: NSRange(location: start, length: singleMatch.range.location - start))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !sub.isEmpty {
                    ruleList.append(SourceRule(ruleStr: sub, mode: detectedMode, isJSON: isJSON))
                }
            }
            let script = extractScriptFromMatch(singleMatch, in: nsStr)
            ruleList.append(SourceRule(ruleStr: script, mode: .jsRule, isJSON: isJSON))
            start = singleMatch.range.location + singleMatch.range.length
        }

        if start < nsStr.length {
            let tail = nsStr.substring(from: start).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty {
                ruleList.append(SourceRule(ruleStr: tail, mode: detectedMode, isJSON: isJSON))
            }
        }

        return ruleList
    }

    private func extractScriptFromMatch(_ singleMatch: NSTextCheckingResult, in nsStr: NSString) -> String {
        if singleMatch.range(at: 1).location != NSNotFound {
            return nsStr.substring(with: singleMatch.range(at: 1))
        } else if singleMatch.range(at: 2).location != NSNotFound {
            return nsStr.substring(with: singleMatch.range(at: 2))
        }
        return ""
    }

    func deduplicateUrls(_ list: [String]) -> [String] {
        var urlList: [String] = []
        for item in list {
            let abs = resolveAbsoluteUrl(item)
            if !abs.isEmpty, !urlList.contains(abs) {
                urlList.append(abs)
            }
        }
        return urlList
    }

    func dispatchElements(rule: String, mode: Mode, cur: Any) -> Any? {
        switch mode {
        case .regex:
            let regs = rule.components(separatedBy: "&&").filter { !$0.isEmpty }
            return AnalyzeByRegex.getElements(res: "\(cur)", regs: regs)

        case .json:
            return JSONPathParser.parseArray(json: "\(cur)", path: rule)

        case .jsRule:
            return evalJS(rule, result: cur)

        default:
            return selectElementsFromDom(rule: rule, cur: cur)
        }
    }

    private func selectElementsFromDom(rule: String, cur: Any) -> Any? {
        if let doc = cur as? Document {
            return CSSSelectorParser.selectElements(element: doc, rule: rule)
        } else if let elem = cur as? Element {
            return CSSSelectorParser.selectElements(element: elem, rule: rule)
        } else {
            let doc = (try? SwiftSoup.parse("\(cur)")) ?? Document("")
            return CSSSelectorParser.selectElements(element: doc, rule: rule)
        }
    }

    // MARK: - 辅助方法

    func executePutRule(_ putMap: [String: String]) {
        for (key, valRule) in putMap {
            let evaluated = getString(valRule)
            put(key, evaluated)
        }
    }
}

// MARK: - Evaluation Helpers

extension AnalyzeRule {
    func evaluateSingleMode(rule: String, mode: Mode, content: Any) -> String? {
        if mode == .jsRule {
            return evalJS(rule, result: content).map { "\($0)" }
        }
        if mode == .json {
            if let dict = content as? [String: Any] {
                return RuleEvaluator.evaluate(dict: dict, rule: rule, baseUrl: baseUrl ?? "")
            }
            return RuleEvaluator.evaluate(json: "\(content)", rule: rule, baseUrl: baseUrl ?? "")
        }
        if mode == .regex {
            return rule
        }
        return evaluateSingleDom(rule: rule, content: content)
    }

    private func evaluateSingleDom(rule: String, content: Any) -> String? {
        if let dict = content as? [String: Any] {
            return RuleEvaluator.evaluate(dict: dict, rule: rule, baseUrl: baseUrl ?? "")
        }
        if let doc = content as? Document {
            return CSSSelectorParser.parseSingle(element: doc, rule: rule, baseUrl: baseUrl)
        } else if let elem = content as? Element {
            return CSSSelectorParser.parseSingle(element: elem, rule: rule, baseUrl: baseUrl)
        }
        let doc = (try? SwiftSoup.parse("\(content)")) ?? Document("")
        return CSSSelectorParser.parseSingle(element: doc, rule: rule, baseUrl: baseUrl)
    }

    func evaluateListMode(rule: String, mode: Mode, content: Any) -> [String] {
        if mode == .jsRule {
            if let res = evalJS(rule, result: content) {
                if let list = res as? [String] {
                    return list
                }
                return ["\(res)"]
            }
            return []
        }
        if mode == .json {
            return JSONPathParser.parse(json: "\(content)", path: rule)
        }
        let doc = (content as? Document) ?? ((try? SwiftSoup.parse("\(content)")) ?? Document(""))
        return CSSSelectorParser.parse(element: doc, rule: rule, baseUrl: baseUrl)
    }

    func applyRegex(to text: String, sourceRule: SourceRule) -> String {
        guard !sourceRule.replaceRegex.isEmpty,
              let regex = try? NSRegularExpression(pattern: sourceRule.replaceRegex, options: []) else {
            return text
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        if sourceRule.replaceFirst {
            if let first = regex.firstMatch(in: text, options: [], range: fullRange) {
                return regex.stringByReplacingMatches(
                    in: text,
                    options: [],
                    range: first.range,
                    withTemplate: sourceRule.replacement)
            }
            return text
        } else {
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: fullRange,
                withTemplate: sourceRule.replacement)
        }
    }

    func resolveAbsoluteUrl(_ relative: String) -> String {
        let trimmed = relative.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseUrl ?? "" }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        if let base = redirectUrl ?? (baseUrl.flatMap { URL(string: $0) }),
           let abs = URL(string: trimmed, relativeTo: base) {
            return abs.absoluteString
        }
        return trimmed
    }

    public static func unescapeHtml(_ html: String) -> String {
        var str = html
        str = str.replacingOccurrences(of: "&nbsp;", with: " ")
        str = str.replacingOccurrences(of: "&quot;", with: "\"")
        str = str.replacingOccurrences(of: "&amp;", with: "&")
        str = str.replacingOccurrences(of: "&lt;", with: "<")
        str = str.replacingOccurrences(of: "&gt;", with: ">")
        str = str.replacingOccurrences(of: "&ldquo;", with: "“")
        str = str.replacingOccurrences(of: "&rdquo;", with: "”")
        str = str.replacingOccurrences(of: "&lsquo;", with: "‘")
        str = str.replacingOccurrences(of: "&rsquo;", with: "’")
        str = str.replacingOccurrences(of: "&#39;", with: "'")
        return str
    }
}
