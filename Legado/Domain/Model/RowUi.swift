import Foundation

/// 书源自定义登录与配置 UI 行组件 (对齐 Android Legado RowUi.kt)
public struct RowUi: Codable, Equatable, Sendable {
    public var name: String
    public var type: String
    public var action: String?
    public var chars: [String?]?
    public var defaultValue: String?
    public var viewName: String?
    public var style: FlexChildStyle?

    public init(
        name: String = "",
        type: String = "text",
        action: String? = nil,
        chars: [String?]? = nil,
        defaultValue: String? = nil,
        viewName: String? = nil,
        style: FlexChildStyle? = nil) {
        self.name = name
        self.type = type
        self.action = action
        self.chars = chars
        self.defaultValue = defaultValue
        self.viewName = viewName
        self.style = style
    }

    public enum RowType {
        public static let text = "text"
        public static let password = "password"
        public static let button = "button"
        public static let toggle = "toggle"
        public static let select = "select"
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case action
        case chars
        case defaultValue = "default"
        case viewName
        case style
    }

    public func effectiveStyle() -> FlexChildStyle {
        style ?? FlexChildStyle.defaultStyle
    }
}
