import SwiftUI

/// 阅读器内置配色主题
public enum ReaderTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case paper // 羊皮纸/暖黄
    case light // 晨曦白
    case eyeCare // 雅致护眼绿
    case dark // 深空灰
    case black // OLED 纯黑

    public var id: String {
        rawValue
    }

    public var name: String {
        switch self {
        case .paper: return "羊皮纸"
        case .light: return "晨曦白"
        case .eyeCare: return "护眼绿"
        case .dark: return "深空灰"
        case .black: return "极夜黑"
        }
    }

    public var backgroundColor: Color {
        switch self {
        case .paper: return Color(red: 0.96, green: 0.93, blue: 0.86)
        case .light: return Color(red: 0.98, green: 0.98, blue: 0.99)
        case .eyeCare: return Color(red: 0.90, green: 0.94, blue: 0.90)
        case .dark: return Color(red: 0.14, green: 0.14, blue: 0.16)
        case .black: return Color.black
        }
    }

    public var textColor: Color {
        switch self {
        case .paper: return Color(red: 0.18, green: 0.15, blue: 0.10)
        case .light: return Color(red: 0.12, green: 0.12, blue: 0.14)
        case .eyeCare: return Color(red: 0.14, green: 0.22, blue: 0.14)
        case .dark: return Color(red: 0.82, green: 0.82, blue: 0.85)
        case .black: return Color(red: 0.65, green: 0.65, blue: 0.68)
        }
    }

    public var isDark: Bool {
        self == .dark || self == .black
    }
}

/// 阅读器字体族
public enum ReaderFontFamily: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "系统默认"
    case songti = "宋体"
    case kaiti = "楷体"

    public var id: String {
        rawValue
    }

    public func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size)

        case .songti:
            return UIFont(name: "Songti SC", size: size) ?? UIFont.systemFont(ofSize: size)

        case .kaiti:
            return UIFont(name: "Kaiti SC", size: size) ?? UIFont.systemFont(ofSize: size)
        }
    }
}

/// 阅读器排版偏好全局配置
public struct ReaderConfig: Equatable, Codable, Sendable {
    public var fontSize: CGFloat
    public var lineSpacing: CGFloat
    public var paragraphSpacing: CGFloat
    public var fontFamily: ReaderFontFamily
    public var theme: ReaderTheme
    public var horizontalMargin: CGFloat
    public var topMargin: CGFloat
    public var bottomMargin: CGFloat

    public init(
        fontSize: CGFloat = 19.0,
        lineSpacing: CGFloat = 8.0,
        paragraphSpacing: CGFloat = 12.0,
        fontFamily: ReaderFontFamily = .system,
        theme: ReaderTheme = .paper,
        horizontalMargin: CGFloat = 18.0,
        topMargin: CGFloat = 50.0,
        bottomMargin: CGFloat = 42.0) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.fontFamily = fontFamily
        self.theme = theme
        self.horizontalMargin = horizontalMargin
        self.topMargin = topMargin
        self.bottomMargin = bottomMargin
    }

    public static let defaultConfig = ReaderConfig()
}
