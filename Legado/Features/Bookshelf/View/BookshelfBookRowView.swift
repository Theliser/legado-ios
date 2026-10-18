import SwiftUI

/// 书架列表行项视图 (iOS 原生液态玻璃质感)
public struct BookshelfBookRowView: View {
    public let book: Book
    public let isBatchMode: Bool
    public let isSelected: Bool
    public let isUpdated: Bool
    public let allGroups: [String]
    public let onTap: () -> Void
    public let onShowDetail: () -> Void
    public let onRemove: () -> Void
    public let onMoveGroup: (String?) -> Void

    public init(
        book: Book,
        isBatchMode: Bool,
        isSelected: Bool,
        isUpdated: Bool,
        allGroups: [String],
        onTap: @escaping () -> Void,
        onShowDetail: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onMoveGroup: @escaping (String?) -> Void) {
        self.book = book
        self.isBatchMode = isBatchMode
        self.isSelected = isSelected
        self.isUpdated = isUpdated
        self.allGroups = allGroups
        self.onTap = onTap
        self.onShowDetail = onShowDetail
        self.onRemove = onRemove
        self.onMoveGroup = onMoveGroup
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                if isBatchMode {
                    selectionCheckbox
                }

                coverImage
                    .frame(width: 54, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                bookDetails

                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.white.opacity(0.18),
                        lineWidth: isSelected ? 1.5 : 0.5))
            .shadow(color: AppTheme.Shadow.glass, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isBatchMode {
                Button(action: onShowDetail) {
                    Label("查看详情与目录", systemImage: "info.circle")
                }

                Menu("移动至分组") {
                    Button("移出分组") {
                        onMoveGroup(nil)
                    }
                    ForEach(allGroups.filter { !["全部", "在读", "未读", "完结"].contains($0) }, id: \.self) { grp in
                        Button(grp) {
                            onMoveGroup(grp)
                        }
                    }
                }

                Button(role: .destructive, action: onRemove) {
                    Label("移出书架", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Subviews

    private var selectionCheckbox: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var coverImage: some View {
        if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(img):
                    img.resizable().scaledToFill()

                default:
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    private var placeholderCover: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.tint)
        }
    }

    private var bookDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(book.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isUpdated {
                    Text("更新")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.red)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(formatProgress(book: book))
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(book.author)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let latest = book.latestChapterTitle, !latest.isEmpty {
                Text("最新: \(latest)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private func formatProgress(book: Book) -> String {
        if book.durChapterIndex == 0 {
            return "未读"
        }
        if book.totalChapterNum > 0 {
            let percent = Int((Double(book.durChapterIndex + 1) / Double(book.totalChapterNum)) * 100)
            return "\(percent)%"
        }
        return "第\(book.durChapterIndex + 1)章"
    }
}
