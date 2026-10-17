import SwiftUI

/// 阅读器液态玻璃控制面板 (HUD Overlay)
public struct ReaderHUDView: View {
    let bookTitle: String
    let currentChapterTitle: String
    let currentChapterIndex: Int
    let totalChapters: Int
    let config: ReaderConfig
    let isConfigOpen: Bool
    let onBack: () -> Void
    let onPreviousChapter: () -> Void
    let onNextChapter: () -> Void
    let onSliderChange: (Double) -> Void
    let onOpenToc: () -> Void
    let onToggleConfig: () -> Void
    let onFontSizeChange: (CGFloat) -> Void
    let onSelectTheme: (ReaderTheme) -> Void
    let onStartTTS: () -> Void

    public init(
        bookTitle: String,
        currentChapterTitle: String,
        currentChapterIndex: Int,
        totalChapters: Int,
        config: ReaderConfig,
        isConfigOpen: Bool,
        onBack: @escaping () -> Void,
        onPreviousChapter: @escaping () -> Void,
        onNextChapter: @escaping () -> Void,
        onSliderChange: @escaping (Double) -> Void,
        onOpenToc: @escaping () -> Void,
        onToggleConfig: @escaping () -> Void,
        onFontSizeChange: @escaping (CGFloat) -> Void,
        onSelectTheme: @escaping (ReaderTheme) -> Void,
        onStartTTS: @escaping () -> Void = {}) {
        self.bookTitle = bookTitle
        self.currentChapterTitle = currentChapterTitle
        self.currentChapterIndex = currentChapterIndex
        self.totalChapters = totalChapters
        self.config = config
        self.isConfigOpen = isConfigOpen
        self.onBack = onBack
        self.onPreviousChapter = onPreviousChapter
        self.onNextChapter = onNextChapter
        self.onSliderChange = onSliderChange
        self.onOpenToc = onOpenToc
        self.onToggleConfig = onToggleConfig
        self.onFontSizeChange = onFontSizeChange
        self.onSelectTheme = onSelectTheme
        self.onStartTTS = onStartTTS
    }

    public var body: some View {
        VStack {
            // 顶部导航栏
            topBar

            Spacer()

            // 底部操作区
            VStack(spacing: 12) {
                // 排版设置浮动面板 (展开时展示)
                if isConfigOpen {
                    typographyPanel
                }

                // 章节进度条与主控制栏
                bottomControlBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - 顶部导航条

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bookTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(currentChapterTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: - 底部主控制栏

    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            // 章节切换滑块
            HStack(spacing: 12) {
                Button(action: onPreviousChapter) {
                    Image(systemName: "backward.fill")
                        .font(.caption)
                }
                .disabled(currentChapterIndex <= 0)

                Slider(
                    value: Binding(
                        get: { Double(currentChapterIndex) },
                        set: { onSliderChange($0) }),
                    in: 0 ... Double(max(totalChapters - 1, 1)),
                    step: 1)
                    .tint(.accentColor)

                Button(action: onNextChapter) {
                    Image(systemName: "forward.fill")
                        .font(.caption)
                }
                .disabled(currentChapterIndex >= totalChapters - 1)
            }
            .padding(.horizontal, 8)

            Divider()

            // 功能快捷按钮
            HStack {
                Button(action: onOpenToc) {
                    VStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.body)
                        Text("目录")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button(action: onToggleConfig) {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                            .font(.body)
                        Text("排版")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button(action: onStartTTS) {
                    VStack(spacing: 4) {
                        Image(systemName: "headphones")
                            .font(.body)
                        Text("听书")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .tint(.primary)
            .padding(.vertical, 4)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    // MARK: - 排版调节浮动面板

    private var typographyPanel: some View {
        VStack(spacing: 14) {
            // 字号调节
            HStack(spacing: 16) {
                Text("字号")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    onFontSizeChange(-1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Text("\(Int(config.fontSize))")
                    .font(.headline.monospacedDigit())
                    .frame(width: 32)

                Button {
                    onFontSizeChange(1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .tint(.primary)

            // 主题配色选择
            HStack(spacing: 12) {
                ForEach(ReaderTheme.allCases) { theme in
                    Button {
                        onSelectTheme(theme)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(theme.backgroundColor)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            config.theme == theme ? Color.accentColor : Color.secondary.opacity(0.2),
                                            lineWidth: config.theme == theme ? 2.5 : 0.5))

                            Text("文")
                                .font(.caption.bold())
                                .foregroundStyle(theme.textColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
