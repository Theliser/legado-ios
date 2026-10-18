import Foundation
import SwiftSoup

/// Legado 统一规则求值器：统一处理 JSONPath、模板插值 {{...}}、正则替换 ##pattern##replace、@js: 脚本及 || / && 组合
public enum RuleEvaluator {
    private static let jsEngine = JSEngine()
    private static let storageLock = NSLock()
    private static var storage: [String: String] = [:]

    public static func getVariable(_ key: String) -> String? {
        storageLock.lock()
        defer { storageLock.unlock() }
        return storage[key]
    }

    public static func putVariable(_ key: String, value: String) {
        storageLock.lock()
        defer { storageLock.unlock() }
        storage[key] = value
    }

    public static func clearVariables() {
        storageLock.lock()
        defer { storageLock.unlock() }
        storage.removeAll()
    }

    /// 针对字典上下文求值单条规则
    public static func evaluate(
        dict: [String: Any],
        rule: String?,
        baseUrl: String = "") -> String? {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var workRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        workRule = handlePutRules(workRule, dict: dict, baseUrl: baseUrl)
        workRule = handleGetRules(workRule)
        guard !workRule.isEmpty else { return nil }

        // 提取顶层全局正则替换 ##pattern##replace
        let (ruleWithoutRegex, regexPairs) = extractRegex(from: workRule)
        workRule = ruleWithoutRegex

        // 提取顶层全局 JavaScript
        let (ruleWithoutScript, jsScript) = extractScript(from: workRule)
        workRule = ruleWithoutScript

        let evaluatedValue = evaluateBranch(workRule: workRule, dict: dict, baseUrl: baseUrl)

        guard var current = evaluatedValue else { return nil }

        // 3. 正则清洗
        if !regexPairs.isEmpty {
            current = applyRegex(to: current, replacements: regexPairs)
        }

        // 4. JavaScript 执行
        if let script = jsScript, let jsOutput = jsEngine.evaluate(script: script, bindings: [
            "result": current,
            "baseUrl": baseUrl,
        ]) {
            current = jsOutput
        }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func evaluateBranch(
        workRule: String,
        dict: [String: Any],
        baseUrl: String) -> String? {
        if workRule.contains("||") {
            let candidates = workRule.components(separatedBy: "||")
            for candidate in candidates {
                if let val = evaluateBaseValue(
                    workRule: candidate.trimmingCharacters(in: .whitespaces),
                    dict: dict,
                    baseUrl: baseUrl), !val.isEmpty {
                    return val
                }
            }
            return nil
        }

        if workRule.contains("&&") {
            let parts = workRule.components(separatedBy: "&&")
            var combined: [String] = []
            for part in parts {
                if let val = evaluateBaseValue(
                    workRule: part.trimmingCharacters(in: .whitespaces),
                    dict: dict,
                    baseUrl: baseUrl), !val.isEmpty {
                    combined.append(val)
                }
            }
            return combined.isEmpty ? nil : combined.joined(separator: " ")
        }

        return evaluateBaseValue(workRule: workRule, dict: dict, baseUrl: baseUrl)
    }

    private static func handlePutRules(_ input: String, dict: [String: Any], baseUrl: String) -> String {
        guard input.contains("@put:{"),
              let regex = try? NSRegularExpression(pattern: #"@put:\{([^:]+):([^}]+)\}"#, options: []) else {
            return input
        }
        var result = input
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        for match in matches.reversed() {
            guard let range0 = Range(match.range(at: 0), in: result),
                  let range1 = Range(match.range(at: 1), in: input),
                  let range2 = Range(match.range(at: 2), in: input) else { continue }
            let key = String(input[range1]).trimmingCharacters(in: .whitespaces)
            let subRule = String(input[range2]).trimmingCharacters(in: .whitespaces)
            if let val = evaluate(dict: dict, rule: subRule, baseUrl: baseUrl) {
                putVariable(key, value: val)
            }
            result.removeSubrange(range0)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func handleGetRules(_ input: String) -> String {
        guard input.contains("@get:{"),
              let regex = try? NSRegularExpression(pattern: #"@get:\{([^}]+)\}"#, options: []) else {
            return input
        }
        var result = input
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        for match in matches.reversed() {
            guard let range0 = Range(match.range(at: 0), in: result),
                  let range1 = Range(match.range(at: 1), in: input) else { continue }
            let key = String(input[range1]).trimmingCharacters(in: .whitespaces)
            let val = getVariable(key) ?? ""
            result.replaceSubrange(range0, with: val)
        }
        return result
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
        let pure = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
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

    private static func evaluateBaseValue(
        workRule: String,
        dict: [String: Any],
        baseUrl: String = "") -> String? {
        var rule = workRule
        if rule.contains("{$"),
           let regex = try? NSRegularExpression(pattern: #"(?<!\{)\{(\$[^}]+)\}(?!\})"#, options: []) {
            let range = NSRange(location: 0, length: rule.utf16.count)
            rule = regex.stringByReplacingMatches(in: rule, options: [], range: range, withTemplate: "{{$1}}")
        }

        if rule.contains("{{"), rule.contains("}}") {
            return interpolateTemplate(rule, dict: dict, baseUrl: baseUrl)
        }
        guard !rule.isEmpty else { return nil }
        var result = extractField(from: dict, path: rule)
        let isPathOrUrl = rule.hasPrefix("/") || rule.hasPrefix("http")
        if result == nil, !rule.hasPrefix("$"), !rule.hasPrefix("@"), isPathOrUrl {
            result = rule
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
    private static func interpolateTemplate(
        _ template: String,
        dict: [String: Any],
        baseUrl: String = "") -> String {
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
            var innerKey = String(template[range1]).trimmingCharacters(in: .whitespaces)
            innerKey = innerKey.replacingOccurrences(of: "\u{a0}", with: " ")
            var val: String?

            if innerKey == "baseUrl" {
                val = baseUrl
            } else if innerKey.hasPrefix("@get:") {
                let varKey = String(innerKey.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
                val = getVariable(varKey)
            } else {
                val = extractField(from: dict, path: innerKey)
                if val == nil || val?.isEmpty == true {
                    let bindings: [String: Any] = [
                        "baseUrl": baseUrl,
                    ]
                    if let jsVal = jsEngine.evaluate(script: innerKey, bindings: bindings) {
                        val = jsVal
                    }
                }
            }
            result.replaceSubrange(range0, with: val ?? "")
        }

        return result
    }

    private static func resolveSegment(current: Any?, seg: String) -> Any? {
        guard let curDict = current as? [String: Any] else { return nil }
        if let openBracket = seg.firstIndex(of: "["),
           let closeBracket = seg.firstIndex(of: "]"),
           openBracket < closeBracket {
            let key = String(seg[..<openBracket])
            let indexStr = String(seg[seg.index(after: openBracket) ..< closeBracket])
            guard let array = curDict[key] as? [Any],
                  let idx = Int(indexStr), idx >= 0, idx < array.count else {
                return nil
            }
            return array[idx]
        }
        return curDict[seg]
    }

    /// 提取单个字段或深层键值 (支持 a.b.c 及 a[0].b 数组索引，以及 $..content 递归查找)
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

        if cleanPath.hasPrefix(".") || cleanPath.contains("..") {
            let targetKey = cleanPath.split(separator: ".").last.map(String.init) ?? cleanPath
            let deepNodes = JSONPathParser.deepFind(key: targetKey, in: dict)
            if let first = deepNodes.first {
                return "\(first)"
            }
        }

        let segments = cleanPath.split(separator: ".").map(String.init)
        var current: Any? = dict
        for seg in segments {
            guard let next = resolveSegment(current: current, seg: seg) else {
                return nil
            }
            current = next
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
        } else if let array = root as? [[String: Any]], let first = array.first {
            return evaluate(dict: first, rule: rule, baseUrl: baseUrl)
        }
        return nil
    }
}
