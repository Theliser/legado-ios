import SwiftUI

/// 书架视图：遵循 MVI 纯渲染范式与 iOS 原生液态玻璃质感
public struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var activeToast: String?
    @State private var searchText = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    groupSelectorView
                    booksGridView
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
                            // 导入本地书籍
                        } label: {
                            Label("导入本地文件", systemImage: "doc.badge.plus")
                        }

                        Button {
                            // 书架整理
                        } label: {
                            Label("整理书架", systemImage: "square.grid.2x2")
                        }

                        Divider()

                        Button {
                            viewModel.send(.refresh)
                        } label: {
                            Label("刷新书架", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // 快速添加或搜索新书
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                viewModel.send(.refresh)
            }
            .onAppear {
                viewModel.send(.onAppear)
            }
            .onReceive(viewModel.effectPublisher) { effect in
                switch effect {
                case let .navigateToReader(id):
                    activeToast = "进入阅读器：\(id.uuidString.prefix(6))"

                case let .showToast(message):
                    activeToast = message
                }
            }
            .overlay(alignment: .top) {
                if let toast = activeToast {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassBackground(cornerRadius: AppTheme.CornerRadius.capsule)
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
                Color(.systemGroupedBackground),
                Color.accentColor.opacity(0.03),
                Color(.systemGroupedBackground),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var groupSelectorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["全部", "连载中", "已完结", "本地缓存"], id: \.self) { group in
                    let isSelected = viewModel.state.selectedGroup == group
                    Button {
                        viewModel.send(.selectGroup(group))
                    } label: {
                        Text(group)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassBackground(
                                cornerRadius: AppTheme.CornerRadius.capsule,
                                material: isSelected ? .regularMaterial : .ultraThinMaterial,
                                hasBorder: true)
                    }
                    .sensoryFeedback(.selection, trigger: viewModel.state.selectedGroup)
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
                ForEach(viewModel.state.books) { book in
                    Button {
                        viewModel.send(.didSelectBook(book.id))
                    } label: {
                        bookRowView(book: book)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: book.id)
                }
            }
        }
    }

    private func bookRowView(book: BookshelfBookItem) -> some View {
        GlassCard(cornerRadius: AppTheme.CornerRadius.large) {
            HStack(spacing: 16) {
                // 封面液态玻璃卡片占位
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                    .frame(width: 54, height: 74)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    }

                // 书籍信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(book.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(Int(book.progressPercent * 100))%")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .glassBackground(cornerRadius: AppTheme.CornerRadius.small)
                    }

                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(book.latestChapter)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}
