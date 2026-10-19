import Foundation

// MARK: - Legacy Compatibility Extension

public extension RuleAnalyzer {
    func extractSingle(content: String, rule: String, baseUrl: String? = nil) -> String? {
        extractList(content: content, rule: rule, baseUrl: baseUrl).first
    }

    func extractList(content: String, rule: String, baseUrl: String? = nil) -> [String] {
        let trimmedRule = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRule.isEmpty else { return [] }

        var mainRule = trimmedRule
        var trailingJS: String?

        if let jsRange = trimmedRule.range(of: "<js>") {
            mainRule = String(trimmedRule[..<jsRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let endTag = "</js>"
            if let endRange = trimmedRule.range(of: endTag) {
                trailingJS = String(trimmedRule[jsRange.upperBound ..< endRange.lowerBound])
            }
        } else if let jsRange = trimmedRule.range(of: "@js:") {
            trailingJS = String(trimmedRule[jsRange.upperBound...])
            mainRule = String(trimmedRule[..<jsRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        var rawResults: [String] = []
        if !mainRule.isEmpty {
            if mainRule.hasPrefix("$.") || mainRule.lowercased().hasPrefix("@json:") {
                rawResults = JSONPathParser.parse(json: content, path: mainRule)
            } else {
                rawResults = CSSSelectorParser.parseElements(html: content, rule: mainRule, baseUrl: baseUrl)
            }
        } else {
            rawResults = [content]
        }

        if let script = trailingJS {
            let jsEngine = JSEngine()
            rawResults = rawResults.compactMap { item in
                jsEngine.evaluate(script: script, bindings: ["result": item, "baseUrl": baseUrl ?? ""])
            }
        }

        return rawResults
    }

    static func applyRegexReplace(text: String, regexRule: String) -> String {
        if let jsResult = evaluateRegexScript(text: text, regexRule: regexRule) {
            return jsResult
        }

        var result = text
        let lines = regexRule.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let part = parseRegexRuleLine(trimmed) else { continue }
            result = applyRegexPart(part, to: result)
        }
        return result
    }

    private static func evaluateRegexScript(text: String, regexRule: String) -> String? {
        let trimmed = regexRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("@js:") || trimmed.hasPrefix("<js>") else { return nil }

        let script: String
        if trimmed.hasPrefix("@js:") {
            script = String(trimmed.dropFirst(4))
        } else if let endIdx = trimmed.range(of: "</js>") {
            let startIdx = trimmed.index(trimmed.startIndex, offsetBy: 4)
            script = String(trimmed[startIdx ..< endIdx.lowerBound])
        } else {
            script = trimmed
        }
        return JSEngine().evaluate(script: script, bindings: ["result": text, "src": text])
    }

    private struct RegexRulePart {
        let pattern: String
        let replacement: String
        let replaceFirst: Bool
    }

    private static func parseRegexRuleLine(_ rule: String) -> RegexRulePart? {
        var pattern = ""
        var replacement = ""
        var replaceFirst = false

        if rule.hasPrefix("##") {
            let parts = rule.components(separatedBy: "##")
            if parts.count >= 2 {
                pattern = parts[1]
                replacement = parts.count > 2 ? parts[2] : ""
                replaceFirst = parts.count > 3
            }
        } else if rule.contains("=>") {
            let parts = rule.components(separatedBy: "=>")
            pattern = parts[0].trimmingCharacters(in: .whitespaces)
            replacement = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        } else if rule.contains("##") {
            let parts = rule.components(separatedBy: "##")
            pattern = parts[0]
            replacement = parts.count > 1 ? parts[1] : ""
            replaceFirst = parts.count > 2
        }

        guard !pattern.isEmpty else { return nil }
        return RegexRulePart(pattern: pattern, replacement: replacement, replaceFirst: replaceFirst)
    }

    private static func applyRegexPart(_ part: RegexRulePart, to text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: part.pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        if part.replaceFirst {
            if let first = regex.firstMatch(in: text, options: [], range: range),
               let matchRange = Range(first.range, in: text) {
                let matchValue = String(text[matchRange])
                let matchNsRange = NSRange(location: 0, length: (matchValue as NSString).length)
                return regex.stringByReplacingMatches(
                    in: matchValue,
                    options: [],
                    range: matchNsRange,
                    withTemplate: part.replacement)
            }
            return ""
        } else {
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: part.replacement)
        }
    }
}
