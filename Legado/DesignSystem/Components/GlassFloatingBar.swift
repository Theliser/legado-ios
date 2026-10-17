import SwiftUI

/// iOS 原生液态玻璃悬浮药丸操作栏 (常用于阅读器控制栏、书架批量操作等)
public struct GlassFloatingBar<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.4),
                        lineWidth: 0.5)
            }
            .shadow(color: AppTheme.Shadow.floating, radius: 16, x: 0, y: 8)
    }
}
