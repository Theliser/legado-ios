import Foundation

/// 发现分类条目 (对齐 Android Legado ExploreKind.kt)
public struct ExploreKind: Codable, Equatable, Sendable {
    public var title: String
    public var url: String?
    public var type: String
    public var action: String?
    public var chars: [String?]?
    public var defaultValue: String?
    public var viewName: String?
    public var style: FlexChildStyle?

    public init(
        title: String = "",
        url: String? = nil,
        type: String = KindType.url,
        action: String? = nil,
        chars: [String?]? = nil,
        defaultValue: String? = nil,
        viewName: String? = nil,
        style: FlexChildStyle? = nil) {
        self.title = title
        self.url = url
        self.type = type
        self.action = action
        self.chars = chars
        self.defaultValue = defaultValue
        self.viewName = viewName
        self.style = style
    }

    public enum KindType {
        public static let url = "url"
        public static let text = "text"
        public static let button = "button"
        public static let toggle = "toggle"
        public static let select = "select"
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case url
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
