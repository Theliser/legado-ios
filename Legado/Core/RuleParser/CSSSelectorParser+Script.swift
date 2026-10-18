import Foundation

extension CSSSelectorParser {
    static func extractScript(from input: String) -> (String, String?) {
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

    static func extractRegex(from input: String) -> (String, [(String, String)]) {
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

    static func applyRegexPairs(_ text: String, pairs: [(String, String)]) -> String {
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
}
