import SwiftUI

// MARK: - ReaderView 内容排版与手势图层扩展

extension ReaderView {
    @ViewBuilder
    func contentLayer(width: CGFloat) -> some View {
        if viewModel.state.isLoading {
            ProgressView("正在排版正文...")
                .tint(viewModel.state.config.theme.textColor)
        } else if viewModel.state.pages.isEmpty {
            ContentUnavailableView(
                "章节内容加载失败",
                systemImage: "book.pages",
                description: Text("轻触屏幕中央呼出控制栏"))
        } else {
            switch viewModel.state.config.pageTurnMode {
            case .cover:
                coverContent(width: width)

            case .slide:
                slideContent(width: width)

            case .scroll:
                scrollContent
            }
        }
    }

    func coverContent(width: CGFloat) -> some View {
        ZStack {
            if let page = viewModel.state.currentPage {
                ReaderPageView(
                    page: page,
                    totalPages: viewModel.state.pages.count,
                    config: viewModel.state.config,
                    highlightedSentence: ttsPlayer.state != .idle ? ttsPlayer.currentSentence : nil)
            }
            tapGestureOverlay(width: width)
        }
    }

    func slideContent(width: CGFloat) -> some View {
        ZStack {
            TabView(selection: Binding(
                get: { viewModel.state.currentPageIndex },
                set: { viewModel.send(.jumpToPage($0)) })) {
                    ForEach(viewModel.state.pages) { page in
                        ReaderPageView(
                            page: page,
                            totalPages: viewModel.state.pages.count,
                            config: viewModel.state.config,
                            highlightedSentence: ttsPlayer.state != .idle ? ttsPlayer.currentSentence : nil)
                            .tag(page.pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

            Color.clear
                .frame(width: width * 0.4)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.send(.toggleHUD)
                }
        }
    }

    var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.state.pages) { page in
                    VStack(alignment: .leading, spacing: 8) {
                        if page.pageIndex == 0 {
                            Text(page.chapterTitle)
                                .font(.title2.bold())
                                .foregroundStyle(viewModel.state.config.theme.textColor)
                                .padding(.bottom, 6)
                        }
                        Text(renderedScrollText(page.contentText))
                            .font(.system(size: viewModel.state.config.fontSize))
                            .lineSpacing(viewModel.state.config.lineSpacing)
                            .foregroundStyle(viewModel.state.config.theme.textColor)
                    }
                    .padding(.horizontal, viewModel.state.config.horizontalMargin)
                }
            }
            .padding(.top, viewModel.state.config.topMargin)
            .padding(.bottom, viewModel.state.config.bottomMargin + 24)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.send(.toggleHUD)
        }
    }

    private func renderedScrollText(_ content: String) -> AttributedString {
        var attr = AttributedString(content)
        if ttsPlayer.state != .idle, !ttsPlayer.currentSentence.isEmpty,
           let range = attr.range(of: ttsPlayer.currentSentence) {
            attr[range].backgroundColor = Color.accentColor.opacity(0.18)
            attr[range].foregroundColor = .accentColor
        }
        return attr
    }

    func tapGestureOverlay(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // 左侧 30% 热区 (上一页)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: width * 0.3)
                .onTapGesture {
                    if viewModel.state.isHUDVisible {
                        viewModel.send(.hideHUD)
                    } else {
                        viewModel.send(.prevPage)
                    }
                }

            // 中间 40% 热区 (呼出/隐藏 HUD)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: width * 0.4)
                .onTapGesture {
                    viewModel.send(.toggleHUD)
                }

            // 右侧 30% 热区 (下一页)
            Color.clear
                .contentShape(Rectangle())
                .frame(width: width * 0.3)
                .onTapGesture {
                    if viewModel.state.isHUDVisible {
                        viewModel.send(.hideHUD)
                    } else {
                        viewModel.send(.nextPage)
                    }
                }
        }
    }
}
