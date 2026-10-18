import Foundation
import SwiftSoup

/// Legado 统一规则求值器：统一处理 JSONPath、模板插值 {{...}}、正则替换 ##pattern##replace、@js: 脚本及 || / && 组合
public enum RuleEvaluator {
    private static let jsEngine = JSEngine()

    /// 针对字典上下文求值单条规则
    public static func evaluate(
        dict: [String: Any],
        rule: String?,
        baseUrl: String = "") -> String? {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let workRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 处理 || 备选分支
        if workRule.contains("||") {
            let candidates = workRule.components(separatedBy: "||")
            for candidate in candidates {
                if let val = evaluate(dict: dict, rule: candidate, baseUrl: baseUrl), !val.isEmpty {
                    return val
                }
            }
            return nil
        }

        // 2. 处理 && 组合拼接
        if workRule.contains("&&") {
            let parts = workRule.components(separatedBy: "&&")
            var combined: [String] = []
            for part in parts {
                if let val = evaluate(dict: dict, rule: part, baseUrl: baseUrl), !val.isEmpty {
                    combined.append(val)
                }
            }
            return combined.isEmpty ? nil : combined.joined(separator: " ")
        }

        return evaluateSingle(dict: dict, rule: workRule, baseUrl: baseUrl)
    }

    private static func evaluateSingle(
        dict: [String: Any],
        rule: String,
        baseUrl: String) -> String? {
        var currentRule = rule

        // 1. 提取脚本
        let (extractedRule, jsScript) = extractScript(from: currentRule)
        currentRule = extractedRule

        // 2. 提取正则替换
        let (pureRule, regexPairs) = extractRegex(from: currentRule)
        currentRule = pureRule

        // 3. 基础值提取
        var result = evaluateBaseValue(workRule: currentRule, dict: dict)

        // 4. 正则清洗
        if var current = result {
            current = applyRegex(to: current, replacements: regexPairs)
            result = current
        }

        // 5. JavaScript 执行
        if let script = jsScript {
            let current = result ?? ""
            if let jsOutput = jsEngine.evaluate(script: script, bindings: [
                "result": current,
                "baseUrl": baseUrl,
            ]) {
                result = jsOutput
            }
        }

        return result?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractScript(from input: String) -> (String, String?) {
        if let jsRange = input.range(of: "@js:") {
            let script = String(input[jsRange.upperBound...])
            let pure = String(input[..<jsRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            return (pure, script)
        } else if let openTag = input.range(of: "<js>"),
                  let closeTag = input.range(of: "</js>") {
            let script = String(input[openTag.upperBound ..< closeTag.lowerBound])
            let before = String(input[..<openTag.lowerBound]).trimmingCharacters(in: .whitespaces)
            let after = String(input[closeTag.upperBound...]).trimmingCharacters(in: .whitespaces)
            let pure = before.isEmpty ? after : before
            return (pure, script)
        }
        return (input, nil)
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

    private static func evaluateBaseValue(workRule: String, dict: [String: Any]) -> String? {
        if workRule.contains("{{"), workRule.contains("}}") {
            return interpolateTemplate(workRule, dict: dict)
        }
        guard !workRule.isEmpty else { return nil }
        var result = extractField(from: dict, path: workRule)
        let isPathOrUrl = workRule.hasPrefix("/") || workRule.hasPrefix("http")
        if result == nil, !workRule.hasPrefix("$"), !workRule.hasPrefix("@"), isPathOrUrl {
            result = workRule
        }
        return result
    }

    private static func applyRegex(to text: String, replacements: [(String, String)]) -> String {
        var current = text
        for (pattern, replacement) in replacements {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            let range = NSRange(current.startIndex ..< current.endIndex, in: current)
            current = regex.stringByReplacingMatches(
                in: current,
                options: [],
                range: range,
                withTemplate: replacement)
        }
        return current
    }

    /// 模板字符串插值：如 "/novels/api/book/{{$.book_id}}" -> "/novels/api/book/12345"
    private static func interpolateTemplate(_ template: String, dict: [String: Any]) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{\{([^}]+)\}\}"#, options: []) else {
            return template
        }

        var result = template
        let fullRange = NSRange(template.startIndex ..< template.endIndex, in: template)
        let matches = regex.matches(in: template, options: [], range: fullRange)

        for match in matches.reversed() {
            guard let range0 = Range(match.range(at: 0), in: result),
                  let range1 = Range(match.range(at: 1), in: template) else {
                continue
            }
            let innerKey = String(template[range1]).trimmingCharacters(in: .whitespaces)
            let val = extractField(from: dict, path: innerKey) ?? ""
            result.replaceSubrange(range0, with: val)
        }

        return result
    }

    /// 提取单个字段或深层键值 (支持 a.b.c 及 a[0].b 数组索引)
    public static func extractField(from dict: [String: Any], path: String) -> String? {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPath.lowercased().hasPrefix("@json:") {
            cleanPath = String(cleanPath.dropFirst(6))
        }
        if cleanPath.hasPrefix("$.") {
            cleanPath = String(cleanPath.dropFirst(2))
        } else if cleanPath.hasPrefix("$") {
            cleanPath = String(cleanPath.dropFirst(1))
        }

        if let val = dict[cleanPath] {
            return "\(val)"
        }

        let segments = cleanPath.split(separator: ".").map(String.init)
        var current: Any? = dict
        for seg in segments {
            if let openBracket = seg.firstIndex(of: "["),
               let closeBracket = seg.firstIndex(of: "]"),
               openBracket < closeBracket {
                let key = String(seg[..<openBracket])
                let indexStr = String(seg[seg.index(after: openBracket) ..< closeBracket])
                guard let curDict = current as? [String: Any],
                      let array = curDict[key] as? [Any],
                      let idx = Int(indexStr), idx >= 0, idx < array.count else {
                    return nil
                }
                current = array[idx]
            } else {
                guard let curDict = current as? [String: Any], let next = curDict[seg] else {
                    return nil
                }
                current = next
            }
        }

        if let current {
            return "\(current)"
        }
        return nil
    }

    /// 针对 JSON 字符串求值
    public static func evaluate(
        json: String,
        rule: String?,
        baseUrl: String = "") -> String? {
        guard let rule, !rule.isEmpty, let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let dict = root as? [String: Any] {
            return evaluate(dict: dict, rule: rule, baseUrl: baseUrl)
        }
        return nil
    }
}
