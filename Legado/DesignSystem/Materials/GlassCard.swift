import SwiftUI

/// 液态玻璃材质修饰符
public struct GlassBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public var cornerRadius: CGFloat
    public var material: Material
    public var hasBorder: Bool
    public var hasShadow: Bool

    public init(
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        material: Material = .ultraThinMaterial,
        hasBorder: Bool = true,
        hasShadow: Bool = true) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.hasBorder = hasBorder
        self.hasShadow = hasShadow
    }

    public func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if hasBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.15)
                                : Color.white.opacity(0.35),
                            lineWidth: 0.5)
                }
            }
            .shadow(
                color: hasShadow ? AppTheme.Shadow.glass : .clear,
                radius: 12,
                x: 0,
                y: 6)
    }
}

public extension View {
    /// 赋予视图 iOS 原生液态玻璃效果
    func glassBackground(
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        material: Material = .ultraThinMaterial,
        hasBorder: Bool = true,
        hasShadow: Bool = true) -> some View {
        modifier(
            GlassBackgroundModifier(
                cornerRadius: cornerRadius,
                material: material,
                hasBorder: hasBorder,
                hasShadow: hasShadow))
    }
}

/// 原生液态玻璃卡片容器
public struct GlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var material: Material
    @ViewBuilder public var content: () -> Content

    public init(
        cornerRadius: CGFloat = AppTheme.CornerRadius.large,
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.content = content
    }

    public var body: some View {
        content()
            .padding()
            .glassBackground(cornerRadius: cornerRadius, material: material)
    }
}
