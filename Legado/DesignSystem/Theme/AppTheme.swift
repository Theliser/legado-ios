import SwiftUI

/// Legado iOS 原生液态玻璃全局主题与动效规范
public enum AppTheme {
    /// 交互弹簧动效规范 (iOS 原生触感阻尼)
    public static let standardSpring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    public static let snappySpring = Animation.spring(response: 0.25, dampingFraction: 0.78)
    public static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.88)

    /// 圆角标准
    public enum CornerRadius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 14
        public static let large: CGFloat = 20
        public static let capsule: CGFloat = 100
    }

    /// 阴影标准
    public enum Shadow {
        public static let glass = Color.black.opacity(0.08)
        public static let floating = Color.black.opacity(0.16)
    }

    /// 品牌与阅读调色板
    public enum Colors {
        public static let brand = Color.accentColor
        public static let paperBackground = Color(red: 0.96, green: 0.94, blue: 0.89)
        public static let oledBackground = Color.black
    }
}
