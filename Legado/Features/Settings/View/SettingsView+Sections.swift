import SwiftUI

// MARK: - SettingsView 辅助分区扩展

extension SettingsView {
    var storageSection: some View {
        Section {
            HStack {
                Text("离线章节缓存")
                Spacer()
                Text(viewModel.state.formattedCacheSize)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                isShowingClearAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空所有离线章节正文")
                }
            }
        } header: {
            Label("存储与离线缓存", systemImage: "internaldrive")
        }
    }

    var purifySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("智能去广告与防盗水印净化")
                        .font(.subheadline.weight(.medium))
                    Text("自动剔除“本章未完请翻页”、推广外链与乱码广告行")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Label("正文净化规则", systemImage: "wand.and.stars")
        }
    }

    var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0 (iOS 18+ 原生)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("视觉风格")
                Spacer()
                Text("Apple Liquid Glass / Vibrancy")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("架构设计")
                Spacer()
                Text("MVI + Clean Architecture")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("开源致敬")
                Spacer()
                Text("Legado (阅读 3.0)")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("关于应用", systemImage: "info.circle")
        }
    }
}
