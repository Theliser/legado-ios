import Foundation
import SwiftSoup

/// 统一规则解析与调度引擎，负责串联 CSS、JSONPath、正则与 JS 脚本
public final class RuleAnalyzer {
    private let jsEngine = JSEngine()

    public init() {}

    /// 解析一段混合规则并返回清洗后的单值结果
    public func extractSingle(content: String, rule: String, baseUrl: String? = nil) -> String? {
        extractList(content: content, rule: rule, baseUrl: baseUrl).first
    }

    /// 解析一段规则并返回结果列表
    public func extractList(content: String, rule: String, baseUrl: String? = nil) -> [String] {
        let trimmedRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRule.isEmpty else { return [] }

        // 1. 判断是否包含 JS 尾随脚本，例如 "rule<js>result.trim()</js>" 或 "@js:..."
        var mainRule = trimmedRule
        var trailingJS: String?

        if let jsRange = trimmedRule.range(of: "<js>") {
            mainRule = String(trimmedRule[..<jsRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let endTag = "</js>"
            if let endRange = trimmedRule.range(of: endTag) {
                trailingJS = String(trimmedRule[jsRange.upperBound ..< endRange.lowerBound])
            }
        } else if trimmedRule.hasPrefix("@js:") {
            trailingJS = String(trimmedRule.dropFirst(4))
            mainRule = ""
        }

        // 2. 调度执行主规则
        var rawResults: [String] = []
        if !mainRule.isEmpty {
            if mainRule.hasPrefix("$.") || mainRule.hasPrefix("@Json:") {
                rawResults = JSONPathParser.parse(json: content, path: mainRule)
            } else {
                rawResults = CSSSelectorParser.parseElements(html: content, rule: mainRule, baseUrl: baseUrl)
            }
        } else {
            rawResults = [content]
        }

        // 3. 执行尾随 JS 处理（如有）
        if let script = trailingJS {
            rawResults = rawResults.compactMap { item in
                jsEngine.evaluate(script: script, bindings: ["result": item, "baseUrl": baseUrl ?? ""])
            }
        }

        return rawResults
    }

    /// 执行正文正则替换：格式为 `##find##replace`
    public func applyRegexReplace(text: String, regexRule: String) -> String {
        let parts = regexRule.components(separatedBy: "##")
        guard parts.count >= 2 else { return text }

        let pattern = parts[1]
        let replacement = parts.count > 2 ? parts[2] : ""

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}
