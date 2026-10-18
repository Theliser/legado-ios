import Foundation

/// 通用规则分词与平衡定界符解析器 (对齐 Android Legado RuleAnalyzer.kt)
///
/// 核心特性：
/// 1. 平衡定界符平衡组算法，在包含嵌套括号 `[]`、`()`、`{}`、引号 `"`/`'` 和转义符 `\` 的规则中安全扫描；
/// 2. 避免将 JsonPath 内部的 `[?(@.a && @.b)]` 谓词误当做阅读的 `&&`、`||`、`%%` 切分；
/// 3. 支持内嵌规则提取：`innerRule("{$.")` 与 `innerRule("{{", "}}")`。
public final class RuleAnalyzer: @unchecked Sendable {
    let chars: [Character]
    var pos = 0
    private var start = 0
    var startX = 0
    private var rule: [String] = []
    private var step = 0
    public var elementsType = ""
    private let code: Bool

    public init(_ data: String = "", code: Bool = false) {
        self.chars = Array(data)
        self.code = code
    }

    private var esc: Character {
        "\\"
    }

    func substring(_ fromIndex: Int, _ toIndex: Int? = nil) -> String {
        let endIndex = toIndex ?? chars.count
        guard fromIndex >= 0, fromIndex <= endIndex, endIndex <= chars.count else { return "" }
        return String(chars[fromIndex ..< endIndex])
    }

    public func reSetPos() {
        pos = 0
        startX = 0
        start = 0
        rule.removeAll()
        step = 0
        elementsType = ""
    }

    public func trim() {
        if pos < chars.count, chars[pos] == "@" || chars[pos] <= "!" {
            pos += 1
            while pos < chars.count, chars[pos] == "@" || chars[pos] <= "!" {
                pos += 1
            }
            start = pos
            startX = pos
        }
    }

    func consumeTo(_ seq: String) -> Bool {
        start = pos
        let seqChars = Array(seq)
        guard !seqChars.isEmpty else { return false }
        var cursor = pos
        while cursor + seqChars.count <= chars.count {
            if chars[cursor ..< (cursor + seqChars.count)].elementsEqual(seqChars) {
                pos = cursor
                return true
            }
            cursor += 1
        }
        return false
    }

    private func consumeToAny(_ seqs: [String]) -> Bool {
        var cursor = pos
        while cursor < chars.count {
            for sequence in seqs {
                let seqChars = Array(sequence)
                if cursor + seqChars.count <= chars.count,
                   chars[cursor ..< (cursor + seqChars.count)].elementsEqual(seqChars) {
                    step = seqChars.count
                    self.pos = cursor
                    return true
                }
            }
            cursor += 1
        }
        return false
    }

    private func findToAny(_ targets: [Character]) -> Int {
        var cursor = pos
        while cursor < chars.count {
            if targets.contains(chars[cursor]) {
                return cursor
            }
            cursor += 1
        }
        return -1
    }

    func chompCodeBalanced(open: Character, close: Character) -> Bool {
        var cursor = pos
        var depth = 0
        var otherDepth = 0
        var inSingleQuote = false
        var inDoubleQuote = false

        while cursor < chars.count {
            let char = chars[cursor]
            cursor += 1
            if char == esc {
                cursor += 1
                continue
            }
            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            }
            if inSingleQuote || inDoubleQuote {
                continue
            }

            updateCodeDepths(char: char, open: open, close: close, depth: &depth, otherDepth: &otherDepth)
            if depth <= 0, otherDepth <= 0 {
                break
            }
        }
        if depth > 0 || otherDepth > 0 {
            return false
        }
        self.pos = cursor
        return true
    }

    private func updateCodeDepths(
        char: Character,
        open: Character,
        close: Character,
        depth: inout Int,
        otherDepth: inout Int) {
        if char == "[" {
            depth += 1
        } else if char == "]" {
            depth -= 1
        } else if depth == 0 {
            if char == open {
                otherDepth += 1
            } else if char == close {
                otherDepth -= 1
            }
        }
    }

    private func chompRuleBalanced(open: Character, close: Character) -> Bool {
        var cursor = pos
        var depth = 0
        var inSingleQuote = false
        var inDoubleQuote = false

        while cursor < chars.count {
            let char = chars[cursor]
            cursor += 1
            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            }

            if inSingleQuote || inDoubleQuote {
                continue
            } else if char == "\\" {
                cursor += 1
                continue
            }

            if char == open {
                depth += 1
            } else if char == close {
                depth -= 1
            }

            if depth <= 0 {
                break
            }
        }
        if depth > 0 {
            return false
        }
        self.pos = cursor
        return true
    }

    private func chompBalanced(open: Character, close: Character) -> Bool {
        code ? chompCodeBalanced(open: open, close: close) : chompRuleBalanced(open: open, close: close)
    }

    public static func splitRule(_ rule: String, _ splits: String...) -> [String] {
        RuleAnalyzer(rule).splitRule(splits)
    }

    public static func splitRule(_ rule: String, _ splits: [String]) -> [String] {
        RuleAnalyzer(rule).splitRule(splits)
    }

    public static func chompCodeBalanced(_ text: String, _ open: Character, _ close: Character) -> String? {
        let analyzer = RuleAnalyzer(text, code: true)
        if analyzer.chompCodeBalanced(open: open, close: close) {
            return analyzer.substring(1, analyzer.pos - 1)
        }
        return nil
    }

    public func splitRule(_ splits: String...) -> [String] {
        splitRule(splits)
    }

    public func splitRule(_ splits: [String]) -> [String] {
        if splits.count == 1 {
            elementsType = splits[0]
            if !consumeTo(elementsType) {
                rule.append(substring(startX))
                return rule
            } else {
                step = elementsType.count
                return splitRuleNext()
            }
        } else if !consumeToAny(splits) {
            rule.append(substring(startX))
            return rule
        }

        let end = pos
        pos = start

        while true {
            let bracketIndex = findToAny(["[", "("])
            if bracketIndex == -1 {
                return appendUntilEnd(end: end)
            }
            if bracketIndex > end {
                return appendBeforeBracket(end: end, bracketIndex: bracketIndex)
            }

            pos = bracketIndex
            let nextChar: Character = (chars[pos] == "[") ? "]" : ")"
            if !chompBalanced(open: chars[pos], close: nextChar) {
                break
            }
            if end <= pos {
                break
            }
        }

        start = pos
        return splitRule(splits)
    }

    private func appendUntilEnd(end: Int) -> [String] {
        rule = [substring(startX, end)]
        elementsType = substring(end, end + step)
        pos = end + step
        while consumeTo(elementsType) {
            rule.append(substring(start, pos))
            pos += step
        }
        rule.append(substring(pos))
        return rule
    }

    private func appendBeforeBracket(end: Int, bracketIndex: Int) -> [String] {
        rule = [substring(startX, end)]
        elementsType = substring(end, end + step)
        pos = end + step
        while consumeTo(elementsType), pos < bracketIndex {
            rule.append(substring(start, pos))
            pos += step
        }
        if pos > bracketIndex {
            startX = start
            return splitRuleNext()
        } else {
            rule.append(substring(pos))
            return rule
        }
    }

    private func splitRuleNext() -> [String] {
        let end = pos
        pos = start

        while true {
            let bracketIndex = findToAny(["[", "("])
            if bracketIndex == -1 {
                return appendUntilEndNext(end: end)
            }
            if bracketIndex > end {
                return appendBeforeBracketNext(end: end, bracketIndex: bracketIndex)
            }

            pos = bracketIndex
            let nextChar: Character = (chars[pos] == "[") ? "]" : ")"
            if !chompBalanced(open: chars[pos], close: nextChar) {
                break
            }
            if end <= pos {
                break
            }
        }

        start = pos
        if !consumeTo(elementsType) {
            rule.append(substring(startX))
            return rule
        } else {
            return splitRuleNext()
        }
    }

    private func appendUntilEndNext(end: Int) -> [String] {
        rule.append(substring(startX, end))
        pos = end + step
        while consumeTo(elementsType) {
            rule.append(substring(start, pos))
            pos += step
        }
        rule.append(substring(pos))
        return rule
    }

    private func appendBeforeBracketNext(end: Int, bracketIndex: Int) -> [String] {
        rule.append(substring(startX, end))
        pos = end + step
        while consumeTo(elementsType), pos < bracketIndex {
            rule.append(substring(start, pos))
            pos += step
        }
        if pos > bracketIndex {
            startX = start
            return splitRuleNext()
        } else {
            rule.append(substring(pos))
            return rule
        }
    }

}
