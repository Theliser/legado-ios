import SwiftUI

/// 搜索页面视图 (纯声明式渲染 View = f(State))
public struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false

    public init(viewModel: SearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground).opacity(0.5),
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 搜索进度指示条 (正在搜索时展示)
                    if viewModel.state.isSearching {
                        VStack(spacing: 4) {
                            ProgressView(value: viewModel.state.searchProgress)
                                .tint(.accentColor)
                                .padding(.horizontal)

                            HStack {
                                Text(viewModel.state.progressText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("取消") {
                                    viewModel.send(.cancelSearch)
                                }
                                .font(.caption2.bold())
                                .tint(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                    }

                    // 主体内容切换
                    if viewModel.state.resultGroups.isEmpty && !viewModel.state.isSearching {
                        if viewModel.state.query.isEmpty {
                            // 历史记录与热门搜索面板
                            emptySearchDashboard
                        } else {
                            // 无匹配结果
                            ContentUnavailableView.search(text: viewModel.state.query)
                        }
                    } else {
                        // 搜索结果列表
                        resultsList
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: Binding(
                    get: { viewModel.state.query },
                    set: { viewModel.send(.updateQuery($0)) }),
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "输入书名或作者...")
            .onSubmit(of: .search) {
                viewModel.send(.submitSearch(viewModel.state.query))
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
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
                }
            }
        }
    }

    // MARK: - 搜索历史与热门标签面板

    private var emptySearchDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 历史搜索
                if !viewModel.state.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("最近搜索")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                viewModel.send(.clearRecentSearches)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.state.recentSearches, id: \.self) { keyword in
                                Button {
                                    viewModel.send(.selectKeyword(keyword))
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption2)
                                        Text(keyword)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                                }
                                .tint(.primary)
                            }
                        }
                    }
                }

                // 大家都在搜
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("热门推荐")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.state.hotKeywords, id: \.self) { keyword in
                            Button {
                                viewModel.send(.selectKeyword(keyword))
                            } label: {
                                Text(keyword)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 聚合搜索结果列表

    private var resultsList: some View {
        List {
            ForEach(viewModel.state.resultGroups) { group in
                SearchResultGroupRow(
                    group: group,
                    isExpanded: viewModel.state.expandedGroupIds.contains(group.id),
                    addedBookUrls: viewModel.state.addedBookUrls,
                    onToggleExpand: {
                        viewModel.send(.toggleExpandGroup(group.id))
                    },
                    onAddSource: { source in
                        viewModel.send(.addToBookshelf(source))
                    })
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 单本书籍聚合行组件

private struct SearchResultGroupRow: View {
    let group: SearchResultGroup
    let isExpanded: Bool
    let addedBookUrls: Set<String>
    let onToggleExpand: () -> Void
    let onAddSource: (SearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 主卡片信息
            HStack(alignment: .top, spacing: 12) {
                // 封面
                if let coverUrl = group.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFill()

                        default:
                            placeholderCover
                        }
                    }
                    .frame(width: 58, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    placeholderCover
                }

                // 标题、作者、最新章节
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(group.name)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        // 书源数量 Badge
                        Button(action: onToggleExpand) {
                            HStack(spacing: 3) {
                                Text("\(group.sources.count) 个书源")
                                    .font(.caption2.bold())
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Text(group.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let kind = group.kind, !kind.isEmpty {
                            Text(kind)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    if let intro = group.intro, !intro.isEmpty {
                        Text(intro)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }

                    if let latest = group.latestChapterTitle, !latest.isEmpty {
                        Text("最新: \(latest)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            // 展开的书源明细列表
            if isExpanded {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 8) {
                    ForEach(group.sources) { source in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.originName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)

                                if let chapter = source.latestChapterTitle {
                                    Text(chapter)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Text("\(source.responseTimeMs)ms")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)

                            // 加入书架按钮
                            let isAdded = addedBookUrls.contains(source.bookUrl)
                            Button {
                                if !isAdded {
                                    onAddSource(source)
                                }
                            } label: {
                                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.body)
                                    .foregroundStyle(isAdded ? .green : .accentColor)
                            }
                            .buttonStyle(.plain)
                            .disabled(isAdded)
                        }
                        .padding(.vertical, 2)
                    }
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
            Color.secondary.opacity(0.15)
            Image(systemName: "book.closed")
                .foregroundStyle(.secondary)
        }
        .frame(width: 58, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - 流式标签容器 (FlowLayout)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
