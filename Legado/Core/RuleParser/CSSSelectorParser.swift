import Foundation
import SwiftSoup

/// 基于 SwiftSoup 的 HTML/CSS 规则解析器，支持 Legado 常见的 `@text`, `@href`, `@src`, `@html`, `||`, `&&` 及 `##` 正则替换
public enum CSSSelectorParser {
    /// 从 HTML 文档中提取字符串列表
    public static func parseElements(html: String, rule: String, baseUrl: String? = nil) -> [String] {
        guard let doc = try? SwiftSoup.parse(html, baseUrl ?? "") else {
            return []
        }
        return parse(element: doc, rule: rule, baseUrl: baseUrl)
    }

    /// 从单个 DOM Element 中按规则提取
    public static func parse(element: Element, rule: String, baseUrl: String? = nil) -> [String] {
        let trimmedRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRule.isEmpty else { return [] }

        if let branchResult = handleBranching(element: element, rule: trimmedRule, baseUrl: baseUrl) {
            return branchResult
        }

        let (pureRule, regexPairs) = extractRegex(from: trimmedRule)
        let (selector, targetAttr) = parseSelectorAndAttr(from: pureRule)

        do {
            let matchedElements: Elements = selector.isEmpty ? Elements([element]) : try element.select(selector)
            var results: [String] = []
            for item in matchedElements {
                let rawValue = extractAttribute(targetAttr, from: item, baseUrl: baseUrl)
                let cleanedValue = applyRegexPairs(rawValue, pairs: regexPairs)
                let trimmed = cleanedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    results.append(trimmed)
                }
            }
            return results
        } catch {
            return []
        }
    }

    private static func handleBranching(element: Element, rule: String, baseUrl: String?) -> [String]? {
        if rule.contains("||") {
            for candidate in rule.components(separatedBy: "||") {
                let res = parse(element: element, rule: candidate, baseUrl: baseUrl)
                if !res.isEmpty {
                    return res
                }
            }
            return []
        }
        if rule.contains("&&") {
            var combined: [String] = []
            for part in rule.components(separatedBy: "&&") {
                combined.append(contentsOf: parse(element: element, rule: part, baseUrl: baseUrl))
            }
            return combined
        }
        return nil
    }

    private static func applyRegexPairs(_ text: String, pairs: [(String, String)]) -> String {
        var value = text
        for (pattern, replacement) in pairs {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(value.startIndex ..< value.endIndex, in: value)
                value = regex.stringByReplacingMatches(
                    in: value,
                    options: [],
                    range: range,
                    withTemplate: replacement)
            }
        }
        return value
    }

    private static func extractRegex(from input: String) -> (String, [(String, String)]) {
        guard input.contains("##") else { return (input, []) }
        let parts = input.components(separatedBy: "##")
        let pure = parts[0].trimmingCharacters(in: .whitespaces)
        var pairs: [(String, String)] = []
        var index = 1
        while index < parts.count {
            let pattern = parts[index]
            let replacement = (index + 1 < parts.count) ? parts[index + 1] : ""
            if !pattern.isEmpty {
                pairs.append((pattern, replacement))
            }
            index += 2
        }
        return (pure, pairs)
    }

    private static func parseSelectorAndAttr(from rule: String) -> (String, String) {
        if rule.hasPrefix("@") {
            return ("", String(rule.dropFirst()).trimmingCharacters(in: .whitespaces).lowercased())
        } else if rule == "text" || rule == "href" || rule == "src" || rule == "html" || rule == "textNodes" {
            return ("", rule.lowercased())
        } else if rule.contains("@") {
            let parts = rule.components(separatedBy: "@")
            let selector = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
            let targetAttr = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces).lowercased() : "text"
            return (selector, targetAttr)
        } else {
            return (rule, "text")
        }
    }

    private static func extractAttribute(_ targetAttr: String, from item: Element, baseUrl: String?) -> String {
        switch targetAttr {
        case "href":
            if let baseUrl, !baseUrl.isEmpty {
                return (try? item.absUrl("href")) ?? (try? item.attr("href")) ?? ""
            }
            return (try? item.attr("href")) ?? ""

        case "src":
            if let baseUrl, !baseUrl.isEmpty {
                return (try? item.absUrl("src")) ?? (try? item.attr("src")) ?? ""
            }
            return (try? item.attr("src")) ?? ""

        case "html":
            return (try? item.html()) ?? ""

        case "text", "textnodes":
            return (try? item.text()) ?? ""

        default:
            return (try? item.attr(targetAttr)) ?? ""
        }
    }

    /// 从单个 Element 提取首个匹配的单值字符串
    public static func parseSingle(element: Element, rule: String, baseUrl: String? = nil) -> String? {
        parse(element: element, rule: rule, baseUrl: baseUrl).first
    }
}
