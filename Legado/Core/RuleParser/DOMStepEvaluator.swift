import Foundation
import SwiftSoup

/// Legado DOM 单步选择器与索引切片执行引擎
enum DOMStepEvaluator {
    enum IndexFilter {
        case none
        case single(Int, isExclude: Bool)
        case slice(start: Int?, end: Int?, step: Int, isExclude: Bool)
    }

    static func selectSingleStep(element: Element, stepRule: String) -> [Element] {
        let (beforeRule, filter) = parseStepIndex(from: stepRule)
        let matched = fetchElementsByBeforeRule(beforeRule, from: element)
        return applyIndexFilter(matched, filter: filter)
    }

    static func parseStepIndex(from rule: String) -> (beforeRule: String, filter: IndexFilter) {
        let trimmed = rule.trimmingCharacters(in: .whitespaces)

        // 1. 括号语法: tag.a[-1:0] 或 children[0] 或 tag.div[!0]
        if trimmed.hasSuffix("]"), let openBracket = trimmed.lastIndex(of: "[") {
            let before = String(trimmed[..<openBracket]).trimmingCharacters(in: .whitespaces)
            var inside = String(trimmed[trimmed.index(after: openBracket) ..< trimmed.index(before: trimmed.endIndex)])
                .trimmingCharacters(in: .whitespaces)

            let isExclude = inside.hasPrefix("!")
            if isExclude {
                inside = String(inside.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            if inside.contains(":") {
                let parts = inside.components(separatedBy: ":")
                let start = Int(parts[0].trimmingCharacters(in: .whitespaces))
                let end = parts.count > 1 ? Int(parts[1].trimmingCharacters(in: .whitespaces)) : nil
                let step = parts.count > 2 ? (Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 1) : 1
                return (before, .slice(start: start, end: end, step: step, isExclude: isExclude))
            } else if let idx = Int(inside) {
                return (before, .single(idx, isExclude: isExclude))
            }
            return (before, .none)
        }

        // 2. 传统点或叹号语法: class.newbox.0, tag.tr!0, tag.p.!-1, class.section.-1
        if let match = matchTrailingIndex(in: trimmed) {
            return match
        }

        return (trimmed, .none)
    }

    private static func matchTrailingIndex(in str: String) -> (beforeRule: String, filter: IndexFilter)? {
        // 匹配切片语法: 如 tag.div.-1:10:2 或 tag.div!-1:10
        let slicePattern = #"^(.*?)(\.|\!)(\-?\d*:\-?\d*(?::\-?\d*)?)$"#
        if let regex = try? NSRegularExpression(pattern: slicePattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) {
            guard let beforeRange = Range(match.range(at: 1), in: str),
                  let delimRange = Range(match.range(at: 2), in: str),
                  let sliceRange = Range(match.range(at: 3), in: str) else {
                return nil
            }
            var before = String(str[beforeRange]).trimmingCharacters(in: .whitespaces)
            if before.hasSuffix(".") {
                before.removeLast()
            }
            let delim = str[delimRange]
            let sliceStr = str[sliceRange]
            let parts = sliceStr.components(separatedBy: ":")
            let start = Int(parts[0].trimmingCharacters(in: .whitespaces))
            let end = parts.count > 1 ? Int(parts[1].trimmingCharacters(in: .whitespaces)) : nil
            let step = parts.count > 2 ? (Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 1) : 1
            return (before, .slice(start: start, end: end, step: step, isExclude: delim == "!"))
        }

        // 匹配单个数字索引: 如 class.newbox.0, tag.tr!0, tag.p.!-1, class.section-list.-1
        let singlePattern = #"^(.*?)(\.|\!)(\-?\d+)$"#
        if let regex = try? NSRegularExpression(pattern: singlePattern),
           let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)) {
            guard let beforeRange = Range(match.range(at: 1), in: str),
                  let delimRange = Range(match.range(at: 2), in: str),
                  let numRange = Range(match.range(at: 3), in: str) else {
                return nil
            }
            var before = String(str[beforeRange]).trimmingCharacters(in: .whitespaces)
            if before.hasSuffix(".") {
                before.removeLast()
            }
            let delim = str[delimRange]
            if let idx = Int(str[numRange]) {
                return (before, .single(idx, isExclude: delim == "!"))
            }
        }

        return nil
    }

    static func fetchElementsByBeforeRule(_ beforeRule: String, from element: Element) -> [Element] {
        let before = beforeRule.trimmingCharacters(in: .whitespaces)
        if before.isEmpty || before == "children" {
            return element.children().array()
        }

        if before.hasPrefix("class.") {
            let cls = String(before.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if cls.contains(".") {
                return (try? element.select("." + cls.replacingOccurrences(of: " ", with: ".")))?.array() ?? []
            } else {
                return (try? element.getElementsByClass(cls))?.array() ?? []
            }
        }

        if before.hasPrefix("tag.") {
            let tag = String(before.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            return (try? element.getElementsByTag(tag))?.array() ?? []
        }

        if before.hasPrefix("id.") {
            let idName = String(before.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if let found = try? element.getElementById(idName) {
                return [found]
            }
            return []
        }

        if before.hasPrefix("text.") {
            let query = String(before.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return (try? element.getElementsContainingOwnText(query))?.array() ?? []
        }

        // 默认回退至 SwiftSoup CSS 选择器
        return (try? element.select(before))?.array() ?? []
    }

    static func applyIndexFilter(_ elements: [Element], filter: IndexFilter) -> [Element] {
        let count = elements.count
        guard count > 0 else { return [] }

        switch filter {
        case .none:
            return elements

        case let .single(idx, isExclude):
            let realIdx = idx < 0 ? count + idx : idx
            if isExclude {
                return elements.enumerated().filter { $0.offset != realIdx }.map(\.element)
            } else {
                if realIdx >= 0, realIdx < count {
                    return [elements[realIdx]]
                }
                return []
            }

        case let .slice(start, end, step, isExclude):
            return applySlice(elements: elements, start: start, end: end, step: step, isExclude: isExclude)
        }
    }

    private static func applySlice(
        elements: [Element],
        start: Int?,
        end: Int?,
        step: Int,
        isExclude: Bool) -> [Element] {
        let count = elements.count
        var startIndex = (start ?? 0) < 0 ? count + (start ?? 0) : (start ?? 0)
        var endIndex = (end ?? (count - 1)) < 0 ? count + (end ?? (count - 1)) : (end ?? (count - 1))
        startIndex = max(0, min(count - 1, startIndex))
        endIndex = max(0, min(count - 1, endIndex))
        let stepSize = max(1, abs(step))

        if isExclude {
            let range = startIndex <= endIndex ? Array(startIndex ... endIndex) : Array(endIndex ... startIndex)
            let excludeSet = Set(range)
            return elements.enumerated().filter { !excludeSet.contains($0.offset) }.map(\.element)
        }

        var results: [Element] = []
        if startIndex <= endIndex {
            var currentIndex = startIndex
            while currentIndex <= endIndex {
                results.append(elements[currentIndex])
                currentIndex += stepSize
            }
        } else {
            var currentIndex = startIndex
            while currentIndex >= endIndex {
                results.append(elements[currentIndex])
                currentIndex -= stepSize
            }
        }
        return results
    }

    static func splitByAtRespectingBrackets(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var bracketDepth = 0
        var parenDepth = 0
        var inSingleQuote = false
        var inDoubleQuote = false

        for char in input {
            if char == "'", !inDoubleQuote {
                inSingleQuote.toggle()
                current.append(char)
            } else if char == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
                current.append(char)
            } else if !inSingleQuote, !inDoubleQuote {
                if char == "[" {
                    bracketDepth += 1
                    current.append(char)
                } else if char == "]" {
                    bracketDepth = max(0, bracketDepth - 1)
                    current.append(char)
                } else if char == "(" {
                    parenDepth += 1
                    current.append(char)
                } else if char == ")" {
                    parenDepth = max(0, parenDepth - 1)
                    current.append(char)
                } else if char == "@", bracketDepth == 0, parenDepth == 0 {
                    parts.append(current)
                    current = ""
                } else {
                    current.append(char)
                }
            } else {
                current.append(char)
            }
        }
        parts.append(current)
        return parts
    }

    static func convertXPathToCSSIfNeeded(_ rule: String) -> String {
        var result = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.hasPrefix("/") else { return rule }

        // 1. 属性与文本提取转换: /text() -> @text, /@attr -> @attr
        result = result.replacingOccurrences(
            of: #"/text\(\)"#,
            with: "@text",
            options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"/@([a-zA-Z0-9_\-]+)"#,
            with: "@$1",
            options: .regularExpression)

        // 2. 节点过滤谓词转换: [@id='...'] -> #..., [@class='...'] -> ....
        result = result.replacingOccurrences(
            of: #"\[@id=['"]([^'"]+)['"]\]"#,
            with: "#$1",
            options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\[@class=['"]([^'"]+)['"]\]"#,
            with: ".$1",
            options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"\[last\(\)\]"#,
            with: "",
            options: .regularExpression)

        // 3. 轴与层级关系转换
        result = result.replacingOccurrences(of: "/following-sibling::", with: " ~ ")
        result = result.replacingOccurrences(of: "//", with: " ")
        result = result.replacingOccurrences(of: "/", with: " ")

        // 4. 清理冗余多余空格
        result = result.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func splitBranchingRespectingScript(_ input: String, separator: String) -> [String] {
        guard input.contains(separator) else { return [input] }

        // 如果包含 @js:，@js: 后面的内容全部视为脚本，不参与前置 || 或 && 分割
        var workRule = input
        var trailingScript = ""
        if let jsRange = input.range(of: "@js:") {
            trailingScript = String(input[jsRange.lowerBound...])
            workRule = String(input[..<jsRange.lowerBound])
        }

        var parts: [String] = []
        var current = ""
        var insideJsTag = false

        let chars = Array(workRule)
        var idx = 0
        let sepChars = Array(separator)
        let sepLen = sepChars.count

        while idx < chars.count {
            if !insideJsTag, idx + 4 <= chars.count, String(chars[idx ..< idx + 4]) == "<js>" {
                insideJsTag = true
                current.append(contentsOf: "<js>")
                idx += 4
                continue
            }
            if insideJsTag, idx + 5 <= chars.count, String(chars[idx ..< idx + 5]) == "</js>" {
                insideJsTag = false
                current.append(contentsOf: "</js>")
                idx += 5
                continue
            }

            if !insideJsTag, idx + sepLen <= chars.count, Array(chars[idx ..< idx + sepLen]) == sepChars {
                let trimmedPart = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedPart.isEmpty {
                    parts.append(trimmedPart)
                }
                current = ""
                idx += sepLen
                continue
            }

            current.append(chars[idx])
            idx += 1
        }

        let lastPart = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastPart.isEmpty {
            parts.append(lastPart)
        }

        return parts.isEmpty ? [input] : parts
    }
}
