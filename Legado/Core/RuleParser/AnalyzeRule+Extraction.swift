import Foundation
import SwiftSoup

// MARK: - AnalyzeRule High-Level Extraction Extension

public extension AnalyzeRule {
    func getString(
        _ ruleStr: String?,
        mContent: Any? = nil,
        isUrl: Bool = false,
        unescape: Bool = true) -> String {
        guard let ruleStr, !ruleStr.isEmpty else { return "" }
        let ruleList = splitSourceRule(ruleStr)
        guard !ruleList.isEmpty else { return "" }

        var result: Any? = mContent ?? self.content
        for sourceRule in ruleList {
            executePutRule(sourceRule.putMap)
            sourceRule.makeUpRule(analyzer: self, result: result)
            guard let cur = result else { continue }
            let rule = sourceRule.rule

            if !rule.isEmpty {
                result = evaluateSingleMode(rule: rule, mode: sourceRule.mode, content: cur)
            }
            if let strRes = result as? String, !sourceRule.replaceRegex.isEmpty {
                result = applyRegex(to: strRes, sourceRule: sourceRule)
            }
        }

        var resultStr = (result as? String) ?? (result != nil ? "\(result!)" : "")
        if unescape, resultStr.contains("&") {
            resultStr = Self.unescapeHtml(resultStr)
        }

        if isUrl {
            return resolveAbsoluteUrl(resultStr)
        }
        return resultStr
    }

    func getStringList(
        _ ruleStr: String?,
        mContent: Any? = nil,
        isUrl: Bool = false) -> [String]? {
        guard let ruleStr, !ruleStr.isEmpty else { return nil }
        let ruleList = splitSourceRule(ruleStr)
        guard !ruleList.isEmpty else { return nil }

        var result: Any? = mContent ?? self.content
        for sourceRule in ruleList {
            executePutRule(sourceRule.putMap)
            sourceRule.makeUpRule(analyzer: self, result: result)
            guard let cur = result else { continue }
            let rule = sourceRule.rule

            if !rule.isEmpty {
                result = evaluateListMode(rule: rule, mode: sourceRule.mode, content: cur)
            }
            result = applyListRegex(result: result, sourceRule: sourceRule)
        }

        guard let result else { return nil }
        let list = convertToList(result)
        return isUrl ? deduplicateUrls(list) : list
    }

    private func applyListRegex(result: Any?, sourceRule: SourceRule) -> Any? {
        guard !sourceRule.replaceRegex.isEmpty else { return result }
        if let list = result as? [String] {
            return list.map { applyRegex(to: $0, sourceRule: sourceRule) }
        } else if let single = result as? String {
            return [applyRegex(to: single, sourceRule: sourceRule)]
        }
        return result
    }

    private func convertToList(_ result: Any) -> [String] {
        if let directList = result as? [String] {
            return directList
        } else if let single = result as? String {
            return single.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        return []
    }

    func getElements(_ ruleStr: String) -> [Any] {
        guard !ruleStr.isEmpty else { return [] }
        let ruleList = splitSourceRule(ruleStr, allInOne: true)
        guard !ruleList.isEmpty else { return [] }

        var result: Any? = self.content
        for sourceRule in ruleList {
            executePutRule(sourceRule.putMap)
            guard let cur = result else { continue }
            let rule = sourceRule.rule
            result = dispatchElements(rule: rule, mode: sourceRule.mode, cur: cur)
        }

        if let array = result as? [Any] {
            return array
        } else if let elements = result as? Elements {
            return elements.array()
        } else if let result {
            return [result]
        }
        return []
    }

    func getElement(_ ruleStr: String) -> Any? {
        getElements(ruleStr).first
    }
}
