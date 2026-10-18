import SwiftUI

/// iOS 原生标准液态玻璃按钮样式（用于次要操作、辅助工具、标签选项）
public struct GlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    public var cornerRadius: CGFloat
    public var isCapsule: Bool

    public init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
        self.isCapsule = false
    }

    public init(isCapsule: Bool) {
        self.cornerRadius = 12
        self.isCapsule = isCapsule
    }

    public func makeBody(configuration: Configuration) -> some View {
        let strokeColor = colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.38)

        Group {
            if isCapsule {
                configuration.label
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(strokeColor, lineWidth: 0.5))
            } else {
                configuration.label
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: 0.5))
            }
        }
        .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
        .opacity(isEnabled ? 1.0 : 0.6)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// iOS 原生着色液态玻璃主要强调按钮样式（用于确认、提交、执行、开始）
public struct GlassProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

    public var tint: Color
    public var cornerRadius: CGFloat
    public var isCapsule: Bool

    public init(tint: Color = .accentColor, cornerRadius: CGFloat = 12) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.isCapsule = false
    }

    public init(tint: Color = .accentColor, isCapsule: Bool) {
        self.tint = tint
        self.cornerRadius = 12
        self.isCapsule = isCapsule
    }

    public func makeBody(configuration: Configuration) -> some View {
        let strokeColor = Color.white.opacity(colorScheme == .dark ? 0.25 : 0.45)

        Group {
            if isCapsule {
                configuration.label
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        ZStack {
                            Rectangle().fill(.ultraThinMaterial)
                            LinearGradient(
                                colors: [
                                    tint.opacity(isEnabled ? 0.88 : 0.4),
                                    tint.opacity(isEnabled ? 0.96 : 0.5),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        }
                    }
                    .clipShape(Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(strokeColor, lineWidth: 0.5))
            } else {
                configuration.label
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background {
                        ZStack {
                            Rectangle().fill(.ultraThinMaterial)
                            LinearGradient(
                                colors: [
                                    tint.opacity(isEnabled ? 0.88 : 0.4),
                                    tint.opacity(isEnabled ? 0.96 : 0.5),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: 0.5))
            }
        }
        .shadow(
            color: isEnabled ? tint.opacity(configuration.isPressed ? 0.15 : 0.3) : .clear,
            radius: configuration.isPressed ? 4 : 8,
            y: configuration.isPressed ? 1 : 4)
        .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
        .opacity(isEnabled ? 1.0 : 0.55)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == GlassButtonStyle {
    /// 默认液态玻璃按钮样式（连续圆角矩形）
    static var glass: GlassButtonStyle {
        GlassButtonStyle()
    }

    /// 胶囊形液态玻璃按钮样式
    static var glassCapsule: GlassButtonStyle {
        GlassButtonStyle(isCapsule: true)
    }

    /// 指定圆角的液态玻璃按钮样式
    static func glass(cornerRadius: CGFloat) -> GlassButtonStyle {
        GlassButtonStyle(cornerRadius: cornerRadius)
    }
}

public extension ButtonStyle where Self == GlassProminentButtonStyle {
    /// 着色高强调液态玻璃按钮样式（默认主题色）
    static var glassProminent: GlassProminentButtonStyle {
        GlassProminentButtonStyle()
    }

    /// 指定主题色的高强调液态玻璃按钮样式
    static func glassProminent(tint: Color, cornerRadius: CGFloat = 12) -> GlassProminentButtonStyle {
        GlassProminentButtonStyle(tint: tint, cornerRadius: cornerRadius)
    }

    /// 胶囊形高强调液态玻璃按钮样式
    static func glassProminentCapsule(tint: Color = .accentColor) -> GlassProminentButtonStyle {
        GlassProminentButtonStyle(tint: tint, isCapsule: true)
    }
}
