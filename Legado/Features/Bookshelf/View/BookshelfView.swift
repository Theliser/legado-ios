import SwiftUI

/// 书架主视图：遵循 MVI 单向数据流与 iOS 18+ 原生液态玻璃美学
public struct BookshelfView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: BookshelfViewModel
    @State private var activeToast: String?
    @State private var selectedBookForDetail: Book?
    @State private var readerDestination: ReaderDestination?
    @State private var hapticTrigger = false
    @State private var isShowingAddGroupAlert = false
    @State private var newGroupName = ""

    public init(viewModel: BookshelfViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.state.searchText },
            set: { viewModel.send(.updateSearchText($0)) })
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    groupSelectorSection

                    if viewModel.state.filteredBooks.isEmpty && !viewModel.state.isLoading {
                        emptyStateView
                    } else if viewModel.state.layoutMode == .grid {
                        booksGridContent
                    } else {
                        booksListContent
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, viewModel.state.isBatchMode ? 90 : 20)
            }
            .navigationTitle("书架")
            .toolbarTitleDisplayMode(.large)
            .searchable(text: searchTextBinding, prompt: "搜索书架中的书籍或作者")
            .toolbar {
                toolbarItems
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
            .fullScreenCover(item: $readerDestination) { dest in
                ReaderView(viewModel: environment.makeReaderViewModel(
                    book: dest.book,
                    initialChapterIndex: dest.chapterIndex))
            }
            .onReceive(viewModel.effectPublisher) { handleEffect($0) }
            .overlay(alignment: .bottom) {
                if viewModel.state.isBatchMode {
                    batchBarOverlay
                }
            }
            .overlay(alignment: .top) {
                toastOverlay
            }
            .alert("新建分组", isPresented: $isShowingAddGroupAlert) {
                TextField("分组名称", text: $newGroupName)
                Button("取消", role: .cancel) { newGroupName = "" }
                Button("确定") {
                    let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        viewModel.send(.addCustomGroup(name: trimmed))
                    }
                    newGroupName = ""
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.send(.toggleLayoutMode)
            } label: {
                Image(systemName: viewModel.state.layoutMode == .grid ? "list.bullet" : "square.grid.2x2")
                    .symbolRenderingMode(.hierarchical)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button {
                    viewModel.send(.toggleBatchMode)
                } label: {
                    Text(viewModel.state.isBatchMode ? "完成" : "管理")
                        .font(.subheadline.weight(.medium))
                }

                Menu {
                    Button {
                        viewModel.send(.refreshAllBookUpdates)
                    } label: {
                        Label("刷新全书架更新", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
    }

    // MARK: - Group Selector

    private var groupSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.state.groups, id: \.self) { group in
                    groupPillView(for: group)
                }

                Button {
                    isShowingAddGroupAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func groupPillView(for group: String) -> some View {
        let isSelected = viewModel.state.selectedGroup == group
        let isCustom = viewModel.state.customGroups.contains(where: { $0.name == group })
        let customGroup = viewModel.state.customGroups.first(where: { $0.name == group })

        return Button {
            viewModel.send(.selectGroup(group))
        } label: {
            Text(group)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? .regularMaterial : .ultraThinMaterial)
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(isSelected ? 0.3 : 0.16), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isCustom, let customGroup {
                Button(role: .destructive) {
                    viewModel.send(.deleteCustomGroup(id: customGroup.id))
                } label: {
                    Label("删除分组「\(group)」", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Books Content

    private var booksGridContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ],
            spacing: 16) {
                ForEach(viewModel.state.filteredBooks) { book in
                    BookshelfBookCardView(
                        book: book,
                        isBatchMode: viewModel.state.isBatchMode,
                        isSelected: viewModel.state.selectedBookUrls.contains(book.bookUrl),
                        isUpdated: viewModel.state.updatedBookUrls.contains(book.bookUrl),
                        allGroups: viewModel.state.groups,
                        onTap: { viewModel.send(.didSelectBook(book)) },
                        onShowDetail: { viewModel.send(.openBookDetail(book)) },
                        onRemove: { viewModel.send(.removeBook(bookUrl: book.bookUrl)) },
                        onMoveGroup: { viewModel.send(.moveBookToGroup(bookUrl: book.bookUrl, groupName: $0)) })
                }
            }
    }

    private var booksListContent: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.state.filteredBooks) { book in
                BookshelfBookRowView(
                    book: book,
                    isBatchMode: viewModel.state.isBatchMode,
                    isSelected: viewModel.state.selectedBookUrls.contains(book.bookUrl),
                    isUpdated: viewModel.state.updatedBookUrls.contains(book.bookUrl),
                    allGroups: viewModel.state.groups,
                    onTap: { viewModel.send(.didSelectBook(book)) },
                    onShowDetail: { viewModel.send(.openBookDetail(book)) },
                    onRemove: { viewModel.send(.removeBook(bookUrl: book.bookUrl)) },
                    onMoveGroup: { viewModel.send(.moveBookToGroup(bookUrl: book.bookUrl, groupName: $0)) })
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            viewModel.state.searchText.isEmpty ? "书架空空如也" : "无搜索结果",
            systemImage: "books.vertical",
            description: Text(viewModel.state.searchText.isEmpty ? "前往搜索页面探索并添加喜爱的小说" : "未找到匹配的书籍"))
            .padding(.top, 40)
    }

    // MARK: - Overlays & Effects

    private var batchBarOverlay: some View {
        BookshelfBatchBar(
            selectedCount: viewModel.state.selectedBookUrls.count,
            isAllSelected: !viewModel.state.filteredBooks.isEmpty &&
                viewModel.state.selectedBookUrls.count == viewModel.state.filteredBooks.count,
            customGroups: viewModel.state.customGroups,
            onToggleSelectAll: {
                if viewModel.state.selectedBookUrls.count == viewModel.state.filteredBooks.count {
                    viewModel.send(.deselectAll)
                } else {
                    viewModel.send(.selectAll)
                }
            },
            onBatchMove: { groupName in
                viewModel.send(.batchMoveSelectedToGroup(groupName: groupName))
            },
            onBatchRemove: {
                viewModel.send(.batchRemoveSelected)
            },
            onFinish: {
                viewModel.send(.toggleBatchMode)
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = activeToast {
            Text(toast)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.black.opacity(0.55)
                    }
                }
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    activeToast = nil
                }
        }
    }

    private func handleEffect(_ effect: BookshelfEffect) {
        switch effect {
        case let .navigateToReader(book):
            readerDestination = ReaderDestination(book: book, chapterIndex: book.durChapterIndex)

        case let .navigateToDetail(book):
            selectedBookForDetail = book

        case let .showToast(message):
            activeToast = message

        case .hapticFeedback:
            hapticTrigger.toggle()
        }
    }
}
