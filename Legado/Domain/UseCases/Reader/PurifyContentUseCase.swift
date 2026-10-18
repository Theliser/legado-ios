import Foundation

/// 正文净化与广告清洗用例
public final class PurifyContentUseCase: Sendable {
    /// 默认全局广告与跳转提示过滤规则
    public static let defaultRules: [ReplaceRule] = [
        ReplaceRule(
            name: "过滤换页提示",
            pattern: "(本章未完|请点击下一[页章]继续阅读|未完待续|点击下一[页章]|第[0-9]+页/共[0-9]+页)",
            replacement: ""),
        ReplaceRule(
            name: "过滤广告推广网址",
            pattern: "((https?://)?([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}(/[a-zA-Z0-9#?&._-]*)?)",
            replacement: ""),
        ReplaceRule(
            name: "过滤阅读APP水印与防盗章节提示",
            pattern: "(笔趣阁.*?最快更新|首发.*?最新章节|最新最快更新|天才一秒记住|手机用户请浏览|请牢记.*?网址|请牢记本站|收藏本站|笔趣阁提醒您)",
            replacement: ""),
    ]

    public init() {}

    /// 执行文本净化清洗
    public func execute(
        content: String,
        sourceUrl: String? = nil,
        customRules: [ReplaceRule] = []) -> String {
        var result = content
        let activeRules = (PurifyContentUseCase.defaultRules + customRules).filter { rule in
            guard rule.isEnabled else { return false }
            if let scope = rule.scopeSourceUrl, let sourceUrl {
                return scope == sourceUrl
            }
            return true
        }

        for rule in activeRules {
            let options: NSString.CompareOptions = rule.isCaseSensitive
                ? [.regularExpression]
                : [.regularExpression, .caseInsensitive]
            result = result.replacingOccurrences(
                of: rule.pattern,
                with: rule.replacement,
                options: options)
        }

        return result
    }
}
