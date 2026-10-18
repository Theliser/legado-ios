import Foundation
import SwiftSoup

/// 基于 SwiftSoup 的 Legado DOM 规则与 CSS 解析引擎
/// 完整支持 Legado 3.0 的 DOM 步进选择链 (@)、索引筛选 (.0, !0, [-1:0])、标签/类名/ID前缀 (tag., class., id., children)、
/// 正则清洗 (##pattern##replace)、@js: 脚本及 || / && 逻辑组合。
public enum CSSSelectorParser {
    private static let jsEngine = JSEngine()

    // MARK: - 公共 API

    /// 从 HTML 文档中提取字符串列表
    public static func parseElements(html: String, rule: String, baseUrl: String? = nil) -> [String] {
        guard let doc = try? SwiftSoup.parse(html, baseUrl ?? "") else {
            return []
        }
        return parse(element: doc, rule: rule, baseUrl: baseUrl)
    }

    /// 从 HTML 文档中解析出匹配的 DOM Element 列表（用于 bookList, chapterList 等）
    public static func selectElements(html: String, rule: String, baseUrl: String? = nil) -> Elements {
        guard let doc = try? SwiftSoup.parse(html, baseUrl ?? "") else {
            return Elements()
        }
        return selectElements(element: doc, rule: rule)
    }

    /// 从 DOM Element 中解析出匹配的子 DOM Element 列表
    public static func selectElements(element: Element, rule: String) -> Elements {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Elements([element]) }

        if let branchElements = handleElementBranching(element: element, rule: trimmed) {
            return branchElements
        }

        // 检查前置 <js> 语法: <js>...</js>followUpRule
        if trimmed.hasPrefix("<js>"),
           let closeTag = trimmed.range(of: "</js>") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 4)
            let script = String(trimmed[start ..< closeTag.lowerBound])
            let followUp = String(trimmed[closeTag.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let initialContent = (try? element.outerHtml()) ?? ""
            let jsOutput = jsEngine.evaluate(
                script: script,
                bindings: [
                    "result": initialContent,
                    "src": initialContent,
                    "baseUrl": "",
                ]) ?? initialContent

            if followUp.isEmpty {
                return Elements()
            } else if let doc = try? SwiftSoup.parse(jsOutput) {
                return selectElements(element: doc, rule: followUp)
            }
        }

        let workRule = DOMStepEvaluator.convertXPathToCSSIfNeeded(trimmed)
        if workRule.lowercased().hasPrefix("@css:") {
            let css = String(workRule.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return (try? element.select(css)) ?? Elements()
        }

        let steps = DOMStepEvaluator.splitByAtRespectingBrackets(workRule)
        var currentElements = [element]

        for step in steps {
            let cleanStep = step.trimmingCharacters(in: .whitespaces)
            guard !cleanStep.isEmpty else { continue }

            var nextElements: [Element] = []
            for cur in currentElements {
                let matching = DOMStepEvaluator.selectSingleStep(element: cur, stepRule: cleanStep)
                nextElements.append(contentsOf: matching)
            }
            currentElements = nextElements
            if currentElements.isEmpty {
                break
            }
        }

        return Elements(currentElements)
    }

    /// 从单个 DOM Element 中按规则提取字符串列表
    public static func parse(element: Element, rule: String, baseUrl: String? = nil) -> [String] {
        let trimmedRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRule.isEmpty else { return [] }

        // 检查前置 <js> 语法: <js>...</js>followUpRule
        if trimmedRule.hasPrefix("<js>"),
           let closeTag = trimmedRule.range(of: "</js>") {
            let start = trimmedRule.index(trimmedRule.startIndex, offsetBy: 4)
            let script = String(trimmedRule[start ..< closeTag.lowerBound])
            let followUp = String(trimmedRule[closeTag.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let initialContent = (try? element.outerHtml()) ?? (try? element.text()) ?? ""
            let jsOutput = jsEngine.evaluate(
                script: script,
                bindings: [
                    "result": initialContent,
                    "src": initialContent,
                    "baseUrl": baseUrl ?? "",
                ]) ?? initialContent

            if followUp.isEmpty {
                let trimmedOut = jsOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmedOut.isEmpty ? [] : [trimmedOut]
            } else if followUp.hasPrefix("$.") || followUp.lowercased().hasPrefix("@json:") {
                return JSONPathParser.parse(json: jsOutput, path: followUp)
            } else {
                return parseElements(html: jsOutput, rule: followUp, baseUrl: baseUrl)
            }
        }

        let (ruleWithoutJs, jsScript) = extractScript(from: trimmedRule)

        if let branchResult = handleStringBranching(element: element, rule: ruleWithoutJs, baseUrl: baseUrl) {
            if let script = jsScript {
                return branchResult.compactMap {
                    jsEngine.evaluate(script: script, bindings: ["result": $0, "baseUrl": baseUrl ?? ""])
                }
            }
            return branchResult
        }

        let (pureRule, regexPairs) = extractRegex(from: ruleWithoutJs)
        let workRule = DOMStepEvaluator.convertXPathToCSSIfNeeded(pureRule)

        let (matchedElements, targetAttr) = resolveElementsAndAttr(from: workRule, root: element)
        var results: [String] = []

        for item in matchedElements {
            var rawValue = extractAttribute(targetAttr, from: item, baseUrl: baseUrl)
            if !regexPairs.isEmpty {
                rawValue = applyRegexPairs(rawValue, pairs: regexPairs)
            }
            if let script = jsScript,
               let jsOutput = jsEngine.evaluate(
                   script: script,
                   bindings: ["result": rawValue, "baseUrl": baseUrl ?? ""]) {
                rawValue = jsOutput
            }
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                results.append(trimmed)
            }
        }
        return results
    }

    /// 从单个 Element 提取首个匹配的单值字符串
    public static func parseSingle(element: Element, rule: String, baseUrl: String? = nil) -> String? {
        parse(element: element, rule: rule, baseUrl: baseUrl).first
    }

    // MARK: - 内部解析与分发

    private static func resolveElementsAndAttr(from rule: String, root: Element) -> (Elements, String) {
        let workRule = rule.trimmingCharacters(in: .whitespaces)
        guard !workRule.isEmpty else { return (Elements([root]), "text") }

        if workRule.lowercased().hasPrefix("@css:") {
            return resolveCssRule(workRule: workRule, root: root)
        }

        if workRule.hasPrefix("@") {
            let attr = String(workRule.dropFirst()).trimmingCharacters(in: .whitespaces)
            return (Elements([root]), attr.isEmpty ? "text" : attr)
        }

        let steps = DOMStepEvaluator.splitByAtRespectingBrackets(workRule)
        if steps.count > 1 {
            let selectorSteps = Array(steps.dropLast())
            let targetAttr = steps.last!.trimmingCharacters(in: .whitespaces)
            var current = [root]
            for step in selectorSteps {
                let cleanStep = step.trimmingCharacters(in: .whitespaces)
                guard !cleanStep.isEmpty else { continue }
                var next: [Element] = []
                for item in current {
                    next.append(contentsOf: DOMStepEvaluator.selectSingleStep(element: item, stepRule: cleanStep))
                }
                current = next
                if current.isEmpty {
                    break
                }
            }
            return (Elements(current), targetAttr.isEmpty ? "text" : targetAttr)
        } else {
            let single = steps[0].trimmingCharacters(in: .whitespaces)
            if isAttributeExtractor(single) {
                return (Elements([root]), single)
            } else {
                let matched = DOMStepEvaluator.selectSingleStep(element: root, stepRule: single)
                return (Elements(matched), "text")
            }
        }
    }

    private static func resolveCssRule(workRule: String, root: Element) -> (Elements, String) {
        let css = String(workRule.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if let lastAt = css.lastIndex(of: "@") {
            let sel = String(css[..<lastAt]).trimmingCharacters(in: .whitespaces)
            let attr = String(css[css.index(after: lastAt)...]).trimmingCharacters(in: .whitespaces)
            let elements = (try? root.select(sel)) ?? Elements()
            return (elements, attr.isEmpty ? "text" : attr)
        } else {
            let elements = (try? root.select(css)) ?? Elements()
            return (elements, "text")
        }
    }

    private static func isAttributeExtractor(_ name: String) -> Bool {
        let lower = name.lowercased()
        let extractors: Set = [
            "text", "textnodes", "owntext", "html", "all",
            "href", "src", "alt", "title", "data-src", "data-original", "data-bid",
            "onclick", "content", "value",
        ]
        return extractors.contains(lower)
    }

    private static func extractAttribute(_ targetAttr: String, from item: Element, baseUrl: String?) -> String {
        let attr = targetAttr.trimmingCharacters(in: .whitespaces).lowercased()
        switch attr {
        case "text":
            return (try? item.text()) ?? ""

        case "textnodes":
            return extractTextNodes(from: item)

        case "owntext":
            return extractOwnText(from: item)

        case "html":
            _ = try? item.select("script, style, noscript").remove()
            return (try? item.html()) ?? ""

        case "all":
            return (try? item.outerHtml()) ?? ""

        case "href", "src":
            return extractUrlAttribute(attr, from: item, baseUrl: baseUrl)

        default:
            let val = (try? item.attr(targetAttr.trimmingCharacters(in: .whitespaces))) ?? ""
            return val.isEmpty ? ((try? item.attr(attr)) ?? "") : val
        }
    }

    private static func extractTextNodes(from item: Element) -> String {
        let nodes = item.textNodes()
        let texts = nodes.compactMap { node -> String? in
            let nodeText = node.text().trimmingCharacters(in: .whitespacesAndNewlines)
            return nodeText.isEmpty ? nil : nodeText
        }
        return texts.isEmpty ? ((try? item.text()) ?? "") : texts.joined(separator: "\n")
    }

    private static func extractOwnText(from item: Element) -> String {
        let own = item.ownText().trimmingCharacters(in: .whitespacesAndNewlines)
        return own.isEmpty ? ((try? item.text()) ?? "") : own
    }

    private static func extractUrlAttribute(_ attr: String, from item: Element, baseUrl: String?) -> String {
        if let baseUrl, !baseUrl.isEmpty {
            let abs = (try? item.absUrl(attr)) ?? ""
            if !abs.isEmpty {
                return abs
            }
        }
        return (try? item.attr(attr)) ?? ""
    }

    private static func handleElementBranching(element: Element, rule: String) -> Elements? {
        if rule.contains("||") {
            let candidates = DOMStepEvaluator.splitBranchingRespectingScript(rule, separator: "||")
            if candidates.count > 1 {
                for candidate in candidates {
                    let res = selectElements(element: element, rule: candidate)
                    if !res.isEmpty() {
                        return res
                    }
                }
                return Elements()
            }
        }
        if rule.contains("&&") {
            let candidates = DOMStepEvaluator.splitBranchingRespectingScript(rule, separator: "&&")
            if candidates.count > 1 {
                var combined: [Element] = []
                for candidate in candidates {
                    let res = selectElements(element: element, rule: candidate)
                    combined.append(contentsOf: res.array())
                }
                return Elements(combined)
            }
        }
        return nil
    }

    private static func handleStringBranching(element: Element, rule: String, baseUrl: String?) -> [String]? {
        if rule.contains("||") {
            let candidates = DOMStepEvaluator.splitBranchingRespectingScript(rule, separator: "||")
            if candidates.count > 1 {
                for candidate in candidates {
                    let res = parse(element: element, rule: candidate, baseUrl: baseUrl)
                    if !res.isEmpty {
                        return res
                    }
                }
                return []
            }
        }
        if rule.contains("&&") {
            let candidates = DOMStepEvaluator.splitBranchingRespectingScript(rule, separator: "&&")
            if candidates.count > 1 {
                var combined: [String] = []
                for part in candidates {
                    combined.append(contentsOf: parse(element: element, rule: part, baseUrl: baseUrl))
                }
                return combined
            }
        }
        return nil
    }
}
