import SwiftUI

/// 液态玻璃正文内容检索抽屉 (Search In Book Content Sheet)
public struct BookSearchContentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookSearchContentViewModel
    @State private var hapticTrigger = false

    private let onSelectMatch: (Int, Int) -> Void

    public init(
        viewModel: BookSearchContentViewModel,
        onSelectMatch: @escaping (Int, Int) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectMatch = onSelectMatch
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if viewModel.state.matches.isEmpty, viewModel.state.isSearching {
                    VStack(spacing: 12) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.1)
                        Text("正在全书章节检索关键词...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else if viewModel.state.matches.isEmpty, !viewModel.state.query.isEmpty {
                    ContentUnavailableView.search(text: viewModel.state.query)
                } else if viewModel.state.matches.isEmpty {
                    ContentUnavailableView(
                        "搜索正文内容",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("输入人名、地名或关键词查找全书对应段落"))
                } else {
                    matchListView
                }
            }
            .navigationTitle("正文搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.fraction(0.65), .large])
        .presentationBackground(.ultraThinMaterial)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .onReceive(viewModel.effectPublisher) { effect in
            switch effect {
            case .dismiss:
                dismiss()

            case let .jumpToChapter(chapterIndex, matchOffset):
                onSelectMatch(chapterIndex, matchOffset)

            case .hapticFeedback:
                hapticTrigger.toggle()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                "输入关键词搜索全书",
                text: Binding(
                    get: { viewModel.state.query },
                    set: { viewModel.send(.updateQuery($0)) }))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !viewModel.state.query.isEmpty {
                Button {
                    viewModel.send(.clear)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)))
    }

    private var matchListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text("共找到 \(viewModel.state.totalMatchesCount) 处匹配")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                ForEach(viewModel.state.matches) { match in
                    matchCard(match)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func matchCard(_ match: BookSearchMatch) -> some View {
        Button {
            viewModel.send(.selectMatch(match))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(match.chapterTitle)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                Text(match.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)))
            .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
