import Foundation

/// 单个分段规则模型 (对齐 Android Legado AnalyzeRule.SourceRule)
public final class SourceRule: @unchecked Sendable {
    public var rule: String
    public var mode: AnalyzeRule.Mode
    public var replaceRegex = ""
    public var replacement = ""
    public var replaceFirst = false
    public var putMap: [String: String] = [:]

    private var ruleParam: [String] = []
    private var ruleType: [Int] = []
    private let getRuleType = -2
    private let jsRuleType = -1
    private let defaultRuleType = 0

    public init(_ ruleStr: String, mode: AnalyzeRule.Mode = .default, isJSON: Bool = false) {
        self.mode = mode
        var currentRule = ruleStr

        if mode != .jsRule, mode != .regex {
            currentRule = Self.resolveMode(from: currentRule, mode: &self.mode, isJSON: isJSON)
        }

        // 1. 分离 @put 规则
        currentRule = Self.extractPutRules(from: currentRule, putMap: &self.putMap)

        // 2. 扫描 @get:{...} 与 {{...}} 模板以及 $1..$9 捕获组
        self.rule = currentRule
        self.parseEvalPatterns(from: currentRule)

        // 3. 分离 ##pattern##replacement[##replaceFirst]
        if self.rule.contains("##") {
            let parts = self.rule.components(separatedBy: "##")
            self.rule = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if parts.count > 1 {
                self.replaceRegex = parts[1]
            }
            if parts.count > 2 {
                self.replacement = parts[2]
            }
            if parts.count > 3 {
                self.replaceFirst = true
            }
        }
    }

    public convenience init(ruleStr: String, mode: AnalyzeRule.Mode = .default, isJSON: Bool = false) {
        self.init(ruleStr, mode: mode, isJSON: isJSON)
    }

    private static func resolveMode(
        from input: String,
        mode: inout AnalyzeRule.Mode,
        isJSON: Bool) -> String {
        if input.uppercased().hasPrefix("@CSS:") {
            mode = .default
            return input
        } else if input.hasPrefix("@@") {
            mode = .default
            return String(input.dropFirst(2))
        } else if input.uppercased().hasPrefix("@XPATH:") {
            mode = .xpath
            return String(input.dropFirst(7))
        } else if input.lowercased().hasPrefix("@json:") {
            mode = .json
            return String(input.dropFirst(6))
        } else if isJSON || input.hasPrefix("$.") || input.hasPrefix("$[") {
            mode = .json
            return input
        } else if input.hasPrefix("/") {
            mode = .xpath
            return input
        }
        return input
    }

    private static func extractPutRules(from input: String, putMap: inout [String: String]) -> String {
        guard input.contains("@put:{"),
              let regex = try? NSRegularExpression(pattern: #"@put:\s*(\{[^}]+\})"#, options: [.caseInsensitive]) else {
            return input
        }
        var result = input
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count))
        for match in matches.reversed() {
            guard let range0 = Range(match.range(at: 0), in: result),
                  let jsonRange = Range(match.range(at: 1), in: input) else { continue }
            let jsonStr = String(input[jsonRange])
            result.removeSubrange(range0)

            if !parseStandardPutJson(jsonStr: jsonStr, putMap: &putMap) {
                parseLenientPutRules(jsonStr: jsonStr, putMap: &putMap)
            }
        }
        return result
    }

    private static func parseStandardPutJson(jsonStr: String, putMap: inout [String: String]) -> Bool {
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        for (keyName, valObj) in dict {
            let cleanKey = keyName.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let cleanVal = "\(valObj)".trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !cleanKey.isEmpty {
                putMap[cleanKey] = cleanVal
            }
        }
        return true
    }

    private static func parseLenientPutRules(jsonStr: String, putMap: inout [String: String]) {
        var inner = jsonStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if inner.hasPrefix("{") {
            inner.removeFirst()
        }
        if inner.hasSuffix("}") {
            inner.removeLast()
        }

        let pairs = inner.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let keyName = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let valStr = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !keyName.isEmpty {
                putMap[keyName] = valStr
            }
        }
    }

    private func parseEvalPatterns(from input: String) {
        guard let regex = try? NSRegularExpression(
            pattern: #"@get:\{([^}]+)\}|\{\{([\s\S]*?)\}\}"#,
            options: []) else {
            splitRegex(input)
            return
        }

        let fullRange = NSRange(location: 0, length: input.utf16.count)
        let matches = regex.matches(in: input, options: [], range: fullRange)
        guard !matches.isEmpty else {
            splitRegex(input)
            return
        }

        if mode != .jsRule, mode != .regex {
            mode = .regex
        }

        var start = 0
        let nsInput = input as NSString
        for match in matches {
            if match.range.location > start {
                let sub = nsInput.substring(with: NSRange(location: start, length: match.range.location - start))
                splitRegex(sub)
            }
            let token = nsInput.substring(with: match.range)
            if token.lowercased().hasPrefix("@get:") {
                ruleType.append(getRuleType)
                let keyRange = match.range(at: 1)
                ruleParam.append(nsInput.substring(with: keyRange).trimmingCharacters(in: .whitespaces))
            } else if token.hasPrefix("{{") {
                ruleType.append(jsRuleType)
                let jsRange = match.range(at: 2)
                ruleParam.append(nsInput.substring(with: jsRange).trimmingCharacters(in: .whitespaces))
            }
            start = match.range.location + match.range.length
        }

        if start < nsInput.length {
            let tail = nsInput.substring(from: start)
            splitRegex(tail)
        }
    }

    private func splitRegex(_ text: String) {
        guard let regex = try? NSRegularExpression(pattern: #"\$(\d{1,2})"#, options: []) else {
            ruleType.append(defaultRuleType)
            ruleParam.append(text)
            return
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        if matches.isEmpty {
            ruleType.append(defaultRuleType)
            ruleParam.append(text)
            return
        }

        var start = 0
        for match in matches {
            if match.range.location > start {
                let sub = nsText.substring(with: NSRange(location: start, length: match.range.location - start))
                ruleType.append(defaultRuleType)
                ruleParam.append(sub)
            }
            let numStr = nsText.substring(with: match.range(at: 1))
            let groupIdx = Int(numStr) ?? 0
            ruleType.append(groupIdx)
            ruleParam.append(nsText.substring(with: match.range))
            start = match.range.location + match.range.length
        }
        if start < nsText.length {
            let tail = nsText.substring(from: start)
            ruleType.append(defaultRuleType)
            ruleParam.append(tail)
        }
    }

    /// 运行时动态补全规则中的 `@get:{...}`、`{{...}}` 与 `$0`~$9
    public func makeUpRule(analyzer: AnalyzeRule, result: Any?) {
        if !ruleParam.isEmpty {
            var resultBuilder = ""
            for index in 0 ..< ruleParam.count {
                let regType = ruleType[index]
                let param = ruleParam[index]
                resultBuilder += resolveParam(regType: regType, param: param, analyzer: analyzer, result: result)
            }
            rule = resultBuilder
        }

        // 分离 ##pattern##replacement[##replaceFirst]
        if rule.contains("##") {
            let parts = rule.components(separatedBy: "##")
            rule = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if parts.count > 1 {
                replaceRegex = parts[1]
            }
            if parts.count > 2 {
                replacement = parts[2]
            }
            if parts.count > 3 {
                replaceFirst = true
            }
        }
    }

    private func resolveParam(
        regType: Int,
        param: String,
        analyzer: AnalyzeRule,
        result: Any?) -> String {
        switch regType {
        case ..<(-1): // getRuleType (-2)
            return analyzer.get(param)

        case -1: // jsRuleType
            if param.hasPrefix("@") || param.hasPrefix("$.") || param.hasPrefix("//") {
                return analyzer.getString(param)
            } else if let eval = analyzer.evalJS(param, result: result) {
                return "\(eval)"
            }
            return ""

        case 0: // defaultRuleType
            return param

        default: // > 0: Regex Group Index
            if let list = result as? [String], regType < list.count {
                return list[regType]
            }
            return param
        }
    }
}
