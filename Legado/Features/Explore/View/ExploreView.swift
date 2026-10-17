import SwiftUI

/// 发现模块视图：纯 MVI 声明式渲染与 iOS 原生液态玻璃质感
public struct ExploreView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: ExploreViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false
    @State private var selectedBookForDetail: Book?

    public init(viewModel: ExploreViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 分类横向滚轮导航
                    if !viewModel.state.categories.isEmpty {
                        categoryChipsView
                    }

                    // 页面主体内容
                    if viewModel.state.isLoadingCategories {
                        ProgressView("正在载入发现分类...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.state.categories.isEmpty {
                        ContentUnavailableView(
                            "暂无发现分类",
                            systemImage: "compass.drawing",
                            description: Text("请在书源管理中导入并启用包含发现规则的书源"))
                            .padding(.top, 40)
                    } else if viewModel.state.isLoadingBooks && viewModel.state.books.isEmpty {
                        ProgressView("正在探索优质好书...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.state.books.isEmpty {
                        ContentUnavailableView(
                            "暂无书籍内容",
                            systemImage: "book.closed",
                            description: Text("该分类下暂未解析到书籍，尝试下拉刷新"))
                            .padding(.top, 40)
                    } else {
                        booksListView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.send(.refresh)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .navigationDestination(item: $selectedBookForDetail) { book in
                BookDetailView(viewModel: environment.makeBookDetailViewModel(book: book))
            }
            .onAppear {
                viewModel.send(.onAppear)
            }
            .onReceive(viewModel.effectPublisher) { effect in
                switch effect {
                case let .navigateToDetail(book):
                    selectedBookForDetail = book

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
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
                }
            }
        }
    }

    // MARK: - 分类横滑胶囊条

    private var categoryChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.state.categories) { category in
                    let isSelected = viewModel.state.selectedCategory?.id == category.id
                    Button {
                        viewModel.send(.selectCategory(category))
                    } label: {
                        Text(category.title)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? .regularMaterial : .ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    // MARK: - 书籍列表呈现

    private var booksListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.state.books) { book in
                Button {
                    viewModel.send(.openBook(book))
                } label: {
                    bookRow(book: book)
                }
                .buttonStyle(.plain)
                .task {
                    if book.id == viewModel.state.books.last?.id {
                        viewModel.send(.loadNextPage)
                    }
                }
            }

            if viewModel.state.isLoadingBooks && !viewModel.state.books.isEmpty {
                ProgressView()
                    .padding(.vertical, 12)
            }
        }
    }

    private func bookRow(book: Book) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // 封面图片
            if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(img):
                        img.resizable().scaledToFill()

                    default:
                        placeholderCover
                    }
                }
                .frame(width: 60, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderCover
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(book.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let kind = book.kind, !kind.isEmpty {
                        Text(kind)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if let intro = book.intro, !intro.isEmpty {
                    Text(intro)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 0.5))
    }

    private var placeholderCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "book.closed")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60, height: 82)
    }
}
