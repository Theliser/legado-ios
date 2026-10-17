import Foundation

/// 正文净化与替换规则领域模型
public struct ReplaceRule: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    /// 规则名称
    public var name: String
    /// 正则表达式模式
    public var pattern: String
    /// 替换目标字符串（默认为空字符串，即移除匹配内容）
    public var replacement: String
    /// 作用域：nil 表示所有书源生效；非 nil 时仅对应书源 URL 生效
    public var scopeSourceUrl: String?
    /// 是否启用
    public var isEnabled: Bool
    /// 是否区分大小写
    public var isCaseSensitive: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        pattern: String,
        replacement: String = "",
        scopeSourceUrl: String? = nil,
        isEnabled: Bool = true,
        isCaseSensitive: Bool = false) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.replacement = replacement
        self.scopeSourceUrl = scopeSourceUrl
        self.isEnabled = isEnabled
        self.isCaseSensitive = isCaseSensitive
    }
}
