import SwiftUI

/// 快速语法助手横向胶囊栏（Liquid Glass 材质与触感反馈）
public struct BookSourceSyntaxChipsBar: View {
    private let tokens: [String] = [
        "@json:",
        "@css:",
        "@xpath:",
        "@js:",
        "<js></js>",
        "##pattern##",
        "{{}}",
        "&&",
        "||",
        "%%",
        "text",
        "href",
        "src",
        "html",
        "all",
        "children",
    ]

    let onSelect: (String) -> Void

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tokens, id: \.self) { token in
                    Button {
                        onSelect(token)
                    } label: {
                        Text(token)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider()
                .opacity(0.3)
        }
    }
}
