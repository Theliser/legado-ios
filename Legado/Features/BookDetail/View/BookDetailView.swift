import SwiftUI

/// 书籍详情页面视图 (纯声明式渲染 View = f(State))
public struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false

    public init(viewModel: BookDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 顶部卡片：封面、书名、作者与关键标签
                headerCard

                // 操作按钮栏：阅读、加入书架、换源
                actionButtons

                // 书籍详细简介
                introCard

                // 目录与最新章节预览卡片
                tocPreviewCard
            }
            .padding(16)
        }
        .background {
            // 背景渐变与毛玻璃环境光
            ZStack {
                Color(uiColor: .systemGroupedBackground)

                if let coverUrl = viewModel.state.book.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        if case let .success(img) = phase {
                            img.resizable()
                                .scaledToFill()
                                .blur(radius: 50)
                                .opacity(0.18)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .navigationTitle(viewModel.state.book.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.send(.loadDetail)
                } label: {
                    if viewModel.state.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.state.isTocPresented },
            set: {
                if !$0 {
                    viewModel.send(.closeToc)
                }
            })) {
                BookTocSheet(
                    chapters: viewModel.state.chapters,
                    durChapterIndex: viewModel.state.book.durChapterIndex,
                    isReverse: viewModel.state.isReverseToc,
                    searchText: viewModel.state.tocSearchText,
                    onToggleReverse: { viewModel.send(.toggleTocReverse) },
                    onSearchChange: { viewModel.send(.updateTocSearch($0)) },
                    onSelectChapter: { viewModel.send(.selectChapter($0)) })
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
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

            case .navigateToReader:
                // 阅读器导航后续里程碑接驳
                break
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
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
            }
        }
    }

    // MARK: - 头部大卡片

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 16) {
            // 封面图
            if let coverUrl = viewModel.state.book.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()

                    default:
                        placeholderCover
                    }
                }
                .frame(width: 100, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            } else {
                placeholderCover
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.state.book.name)
                    .font(.title3.bold())
                    .lineLimit(2)

                Text(viewModel.state.book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if let kind = viewModel.state.book.kind, !kind.isEmpty {
                        Text(kind)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if let wordCount = viewModel.state.book.wordCount, !wordCount.isEmpty {
                        Text(wordCount)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.caption2)
                    Text("当前书源: \(viewModel.state.book.originName)")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.15), lineWidth: 0.5))
    }

    private var placeholderCover: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            Image(systemName: "book.closed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
        .frame(width: 100, height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 操作按钮栏

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // 开始阅读按钮
            Button {
                viewModel.send(.selectChapter(
                    viewModel.state.chapters.first ?? Chapter(url: "", title: "", bookUrl: "", index: 0)))
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                    Text(viewModel.state.book.durChapterIndex > 0 ? "继续阅读" : "开始阅读")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 加入书架按钮
            Button {
                viewModel.send(.toggleBookshelf)
            } label: {
                HStack {
                    Image(
                        systemName: viewModel.state.isInBookshelf ? "bookmark.slash.fill" : "bookmark.fill")
                    Text(viewModel.state.isInBookshelf ? "移出书架" : "加入书架")
                }
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .foregroundStyle(viewModel.state.isInBookshelf ? .red : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5))
            }
        }
    }

    // MARK: - 简介卡片

    private var introCard: some View {
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

    // MARK: - 目录与最新章节预览卡片

    private var tocPreviewCard: some View {
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
