import SwiftUI

// MARK: - BookDetailView 辅助卡片扩展

extension BookDetailView {
    var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("作品简介")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(viewModel.state.book.intro ?? "暂无简介内容")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 0.5))
    }

    var tocPreviewCard: some View {
        Button {
            viewModel.send(.openToc)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("目录")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("共 \(viewModel.state.chapters.count) 章")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let latest = viewModel.state.book.latestChapterTitle, !latest.isEmpty {
                        Text("最新: \(latest)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
