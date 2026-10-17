import Foundation
import SwiftSoup

/// 基于 SwiftSoup 的 HTML/CSS 规则解析器，支持 Legado 常见的 `@text`, `@href`, `@src`, `@html` 属性语法
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

        // 处理 @ 属性提取分隔符，例如 "a.title@href", "img@src", "p@text"
        let parts = trimmedRule.components(separatedBy: "@")
        let selector = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let targetAttr = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces).lowercased() : "text"

        do {
            let matchedElements: Elements
            if selector.isEmpty {
                matchedElements = Elements([element])
            } else {
                matchedElements = try element.select(selector)
            }

            var results: [String] = []
            for item in matchedElements {
                let value = extractAttribute(targetAttr, from: item, baseUrl: baseUrl)
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    results.append(trimmed)
                }
            }
            return results
        } catch {
            return []
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
