import SwiftUI

/// 书架宫格封面卡片视图 (iOS 原生液态玻璃质感)
public struct BookshelfBookCardView: View {
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
            VStack(alignment: .leading, spacing: 8) {
                coverSection
                infoSection
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.white.opacity(0.18),
                        lineWidth: isSelected ? 2 : 0.5))
            .shadow(color: AppTheme.Shadow.glass, radius: 8, x: 0, y: 4)
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

    private var coverSection: some View {
        ZStack(alignment: .topTrailing) {
            bookCoverImage
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 批量选择勾选框
            if isBatchMode {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.black.opacity(0.35))
                        .frame(width: 26, height: 26)
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(6)
            } else if isUpdated {
                // 更新提示角标
                Text("更新")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .padding(6)
            }

            // 底部进度药丸
            VStack {
                Spacer()
                HStack {
                    Text(formatProgress(book: book))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    Spacer()
                }
                .padding(6)
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(book.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 38, alignment: .topLeading)

            Text(book.author)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var bookCoverImage: some View {
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
            VStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(book.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
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
