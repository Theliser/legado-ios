import SwiftUI

/// 书籍离线缓存管理抽屉 (遵循 iOS 原生液态玻璃与 HIG 规范)
public struct BookCacheSheet: View {
    public let book: Book
    public let chapters: [Chapter]
    public let cacheInfo: BookCacheInfo?
    public let downloadProgress: BatchDownloadProgress?
    public let onStartDownload: (BatchDownloadOption) -> Void
    public let onCancelDownload: () -> Void
    public let onClearCache: () -> Void
    public let onDismiss: () -> Void

    @State private var isShowingClearAlert = false

    public init(
        book: Book,
        chapters: [Chapter],
        cacheInfo: BookCacheInfo?,
        downloadProgress: BatchDownloadProgress?,
        onStartDownload: @escaping (BatchDownloadOption) -> Void,
        onCancelDownload: @escaping () -> Void,
        onClearCache: @escaping () -> Void,
        onDismiss: @escaping () -> Void) {
        self.book = book
        self.chapters = chapters
        self.cacheInfo = cacheInfo
        self.downloadProgress = downloadProgress
        self.onStartDownload = onStartDownload
        self.onCancelDownload = onCancelDownload
        self.onClearCache = onClearCache
        self.onDismiss = onDismiss
    }

    private var isDownloading: Bool {
        downloadProgress?.status == .downloading
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 状态与空间卡片
                    cacheStatusCard

                    // 下载进度卡片 (下载中展示)
                    if let progress = downloadProgress, isDownloading {
                        downloadProgressCard(progress: progress)
                    }

                    // 快捷下载选项卡片
                    downloadOptionsSection

                    // 空间清理选项
                    if let info = cacheInfo, info.cachedCount > 0 {
                        clearCacheButton(info: info)
                    }
                }
                .padding(16)
            }
            .navigationTitle("离线缓存管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", action: onDismiss)
                        .font(.subheadline.bold())
                }
            }
            .alert("清空本书缓存", isPresented: $isShowingClearAlert) {
                Button("取消", role: .cancel) {}
                Button("确定清空", role: .destructive, action: onClearCache)
            } message: {
                Text("确定要删除《\(book.name)》已下载的所有离线正文吗？此操作不可逆。")
            }
        }
        .presentationDetents([.fraction(0.6), .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Subviews

    private var cacheStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("共 \(chapters.count) 章 · 已缓存 \(cacheInfo?.cachedCount ?? 0) 章")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let info = cacheInfo {
                    Text(info.formattedSize)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // 缓存进度条
            let progressValue = Double(cacheInfo?.cachedCount ?? 0) / Double(max(1, chapters.count))
            ProgressView(value: progressValue)
                .tint(Color.accentColor)

            HStack {
                Text("缓存率: \(cacheInfo?.percentage ?? 0)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("书源: \(book.originName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5))
    }

    private func downloadProgressCard(progress: BatchDownloadProgress) -> some View {
        VStack(spacing: 10) {
            HStack {
                Label("正在并发下载中...", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Button("取消", action: onCancelDownload)
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }

            ProgressView(value: progress.progress)
                .tint(Color.accentColor)

            HStack {
                if let title = progress.currentChapterTitle {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(progress.completedChaptersCount) / \(progress.totalChaptersToDownload) 章")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
    }

    private var downloadOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("批量缓存快捷选项")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(BatchDownloadOption.allCases) { option in
                    Button {
                        onStartDownload(option)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: iconForOption(option))
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                            Text(option.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .disabled(isDownloading)
                }
            }
        }
    }

    private func clearCacheButton(info: BookCacheInfo) -> some View {
        Button(role: .destructive) {
            isShowingClearAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("清空本书缓存 (释放 \(info.formattedSize))")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func iconForOption(_ option: BatchDownloadOption) -> String {
        switch option {
        case .next50: return "arrow.down.to.line"
        case .next100: return "arrow.down.to.line.compact"
        case .allUnread: return "book.circle"
        case .all: return "square.and.arrow.down.on.square"
        }
    }
}
