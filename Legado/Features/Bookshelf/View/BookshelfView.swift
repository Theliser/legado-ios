import SwiftUI

/// 书架视图：遵循 MVI 纯渲染范式与 iOS 原生液态玻璃质感
public struct BookshelfView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: BookshelfViewModel
    @State private var activeToast: String?
    @State private var searchText = ""
    @State private var selectedBookForDetail: Book?
    @State private var hapticTrigger = false

    public init(viewModel: BookshelfViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var filteredBooks: [Book] {
        var list = viewModel.state.books

        // 分组过滤
        switch viewModel.state.selectedGroup {
        case "在读":
            list = list.filter { $0.durChapterIndex > 0 }

        case "未读":
            list = list.filter { $0.durChapterIndex == 0 }

        case "完结":
            list = list.filter { $0.kind?.contains("完结") == true }

        default:
            break
        }

        // 搜索过滤
        if !searchText.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                    $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        return list
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    groupSelectorView

                    if filteredBooks.isEmpty && !viewModel.state.isLoading {
                        ContentUnavailableView(
                            searchText.isEmpty ? "书架空空如也" : "无搜索结果",
                            systemImage: "books.vertical",
                            description: Text(searchText.isEmpty ? "前往搜索页面探索并添加喜爱的小说" : "未找到匹配的书籍"))
                            .padding(.top, 40)
                    } else {
                        booksGridView
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(backgroundLayer)
            .navigationTitle("书架")
            .toolbarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索书架中的书籍或作者")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.send(.refresh)
                        } label: {
                            Label("刷新书架章节更新", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .refreshable {
                viewModel.send(.refresh)
            }
            .onAppear {
                viewModel.send(.onAppear)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .navigationDestination(item: $selectedBookForDetail) { book in
                BookDetailView(viewModel: environment.makeBookDetailViewModel(book: book))
            }
            .onReceive(viewModel.effectPublisher) { effect in
                switch effect {
                case let .navigateToReader(book):
                    // 阅读器导航
                    activeToast = "进入阅读：《\(book.name)》"

                case let .navigateToDetail(book):
                    selectedBookForDetail = book

                case let .showToast(message):
                    activeToast = message

                case .hapticFeedback:
                    hapticTrigger.toggle()
                }
            }
            .overlay(alignment: .top) {
                if let toast = activeToast {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            activeToast = nil
                        }
                }
            }
        }
    }

    // MARK: - Subviews

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color.accentColor.opacity(0.03),
                Color(uiColor: .systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var groupSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.state.groups, id: \.self) { group in
                    let isSelected = viewModel.state.selectedGroup == group
                    Button {
                        viewModel.send(.selectGroup(group))
                    } label: {
                        Text(group)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isSelected ? .regularMaterial : .ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    private var booksGridView: some View {
        LazyVStack(spacing: 12) {
            if viewModel.state.isLoading && viewModel.state.books.isEmpty {
                ProgressView("正在同步书架...")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(filteredBooks) { book in
                    Button {
                        viewModel.send(.openBookDetail(book))
                    } label: {
                        bookRowView(book: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            viewModel.send(.openBookDetail(book))
                        } label: {
                            Label("查看详情与目录", systemImage: "info.circle")
                        }

                        Button(role: .destructive) {
                            viewModel.send(.removeBook(bookUrl: book.bookUrl))
                        } label: {
                            Label("移出书架", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func bookRowView(book: Book) -> some View {
        HStack(spacing: 14) {
            // 封面图片或占位
            if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(img):
                        img.resizable().scaledToFill()

                    default:
                        placeholderCover
                    }
                }
                .frame(width: 54, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                placeholderCover
            }

            // 书籍信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(book.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // 阅读进度标签
                    let progressText = formatProgress(book: book)
                    Text(progressText)
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
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.15), lineWidth: 0.5))
    }

    private var placeholderCover: some View {
        ZStack {
            Color.accentColor.opacity(0.12)
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .frame(width: 54, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 6))
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
