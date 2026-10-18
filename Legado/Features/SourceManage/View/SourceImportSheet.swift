import SwiftUI
import UIKit

/// 书源导入液态玻璃面板
public struct SourceImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    let onImport: (String) -> Void

    public init(onImport: @escaping (String) -> Void) {
        self.onImport = onImport
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("支持输入书源网络 URL 地址 (http/https)，或直接粘贴单个或批量书源 JSON 内容。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 输入区域
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5))

                    if inputText.isEmpty {
                        Text("粘贴书源 URL 或 JSON 内容...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(14)
                    }

                    TextEditor(text: $inputText)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                }
                .frame(minHeight: 130, maxHeight: 180)

                // 快捷操作按钮
                HStack(spacing: 12) {
                    Button {
                        if let clipboard = UIPasteboard.general.string {
                            inputText = clipboard
                        }
                    } label: {
                        Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass(cornerRadius: 12))

                    Button {
                        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onImport(trimmed)
                        }
                    } label: {
                        Label("确认导入", systemImage: "square.and.arrow.down.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent(tint: .accentColor, cornerRadius: 12))
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("导入书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
}
