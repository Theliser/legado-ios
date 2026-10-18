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
        var result = text
        let lines = regexRule.components(separatedBy: .newlines)
        for line in lines {
            let rule = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rule.isEmpty else { continue }

            var pattern = ""
            var replacement = ""

            if rule.hasPrefix("##") {
                let parts = rule.components(separatedBy: "##")
                if parts.count >= 2 {
                    pattern = parts[1]
                    replacement = parts.count > 2 ? parts[2] : ""
                }
            } else if rule.contains("=>") {
                let parts = rule.components(separatedBy: "=>")
                pattern = parts[0].trimmingCharacters(in: .whitespaces)
                replacement = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            } else if rule.contains("##") {
                let parts = rule.components(separatedBy: "##")
                pattern = parts[0]
                replacement = parts.count > 1 ? parts[1] : ""
            }

            guard !pattern.isEmpty,
                  let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
        }
        return result
    }
}
