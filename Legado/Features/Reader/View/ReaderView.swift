import SwiftUI

/// 沉浸式阅读器主视图 (纯声明式渲染 View = f(State))
public struct ReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: ReaderViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false
    @State private var isTTSSpeaking = false
    @State private var isChangeSourcePresented = false

    public init(viewModel: ReaderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景配色
                viewModel.state.config.theme.backgroundColor
                    .ignoresSafeArea()

                // 多模式正文排版呈现 (覆盖 / 滑动 / 连续上下滚动)
                contentLayer(width: geometry.size.width)

                // 液态玻璃 HUD 控制面板
                if viewModel.state.isHUDVisible {
                    ReaderHUDView(
                        bookTitle: viewModel.state.book.name,
                        currentChapterTitle: viewModel.state.currentChapter?.title ?? "",
                        currentChapterIndex: viewModel.state.currentChapterIndex,
                        totalChapters: viewModel.state.chapters.count,
                        config: viewModel.state.config,
                        isConfigOpen: viewModel.state.isConfigSheetVisible,
                        onBack: { dismiss() },
                        onPreviousChapter: {
                            viewModel.send(.loadChapter(viewModel.state.currentChapterIndex - 1))
                        },
                        onNextChapter: {
                            viewModel.send(.loadChapter(viewModel.state.currentChapterIndex + 1))
                        },
                        onSliderChange: { newIndex in
                            viewModel.send(.loadChapter(Int(newIndex)))
                        },
                        onOpenToc: { viewModel.send(.openToc) },
                        onToggleConfig: { viewModel.send(.openConfig) },
                        onFontSizeChange: { delta in
                            viewModel.send(.changeFontSize(delta: delta))
                        },
                        onSelectTheme: { theme in
                            viewModel.send(.selectTheme(theme))
                        },
                        onSelectPageTurnMode: { mode in
                            viewModel.send(.selectPageTurnMode(mode))
                        },
                        onStartTTS: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                viewModel.send(.toggleHUD)
                                isTTSSpeaking = true
                            }
                            let text = viewModel.state.currentChapterText
                            TTSPlayer.shared.startReading(
                                content: text,
                                bookTitle: viewModel.state.book.name,
                                chapterTitle: viewModel.state.currentChapter?.title ?? "",
                                author: viewModel.state.book.author)
                        },
                        onOpenChangeSource: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                viewModel.send(.hideHUD)
                                isChangeSourcePresented = true
                            }
                        })
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                // 朗读悬浮控制胶囊条
                if isTTSSpeaking {
                    VStack {
                        Spacer()
                        TTSFloatingBar {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                isTTSSpeaking = false
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                viewModel.send(.updateScreenBounds(geometry.frame(in: .local)))
            }
            .onDisappear {
                TTSPlayer.shared.stop()
            }
            .onChange(of: geometry.size) { _, newSize in
                viewModel.send(.updateScreenBounds(CGRect(origin: .zero, size: newSize)))
            }
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(!viewModel.state.isHUDVisible)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .sheet(isPresented: $isChangeSourcePresented) {
            ChangeSourceSheet(
                viewModel: environment.makeChangeSourceViewModel(
                    book: viewModel.state.book,
                    currentChapterTitle: viewModel.state.currentChapter?.title,
                    currentChapterIndex: viewModel.state.currentChapterIndex),
                onSwitched: { updatedBook, newToc, matchedIndex in
                    viewModel.send(.switchSource(
                        updatedBook: updatedBook,
                        newToc: newToc,
                        matchedChapterIndex: matchedIndex))
                })
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.isTocSheetVisible },
            set: {
                if !$0 {
                    viewModel.send(.closeToc)
                }
            })) {
                BookTocSheet(
                    chapters: viewModel.state.chapters,
                    durChapterIndex: viewModel.state.currentChapterIndex,
                    isReverse: false,
                    searchText: "",
                    onToggleReverse: {},
                    onSearchChange: { _ in },
                    onSelectChapter: { chapter in
                        viewModel.send(.closeToc)
                        viewModel.send(.loadChapter(chapter.index))
                    })
        }
        .onReceive(viewModel.effectPublisher) { effect in
            switch effect {
            case let .showToast(msg):
                toastMessage = msg
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if toastMessage == msg {
                        toastMessage = nil
                    }
                }

            case .hapticFeedback:
                hapticTrigger.toggle()

            case .navigateBack:
                dismiss()
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
            }
        }
    }

    @ViewBuilder
    private func contentLayer(width: CGFloat) -> some View {
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

    private func coverContent(width: CGFloat) -> some View {
        ZStack {
            if let page = viewModel.state.currentPage {
                ReaderPageView(
                    page: page,
                    totalPages: viewModel.state.pages.count,
                    config: viewModel.state.config)
            }
            tapGestureOverlay(width: width)
        }
    }

    private func slideContent(width: CGFloat) -> some View {
        ZStack {
            TabView(selection: Binding(
                get: { viewModel.state.currentPageIndex },
                set: { viewModel.send(.jumpToPage($0)) })) {
                    ForEach(viewModel.state.pages) { page in
                        ReaderPageView(
                            page: page,
                            totalPages: viewModel.state.pages.count,
                            config: viewModel.state.config)
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

    private var scrollContent: some View {
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
                        Text(page.contentText)
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

    private func tapGestureOverlay(width: CGFloat) -> some View {
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
