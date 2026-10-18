import SwiftUI

/// 书源管理视图：遵循 MVI 纯渲染与 iOS 原生液态玻璃质感
public struct SourceManageView: View {
    @StateObject var viewModel: SourceManageViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false

    public init(viewModel: SourceManageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    groupFilterBar

                    healthCheckProgressBar

                    if viewModel.state.isLoading && viewModel.state.sources.isEmpty {
                        ProgressView("正在加载书源列表...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.state.filteredSources.isEmpty {
                        ContentUnavailableView(
                            viewModel.state.searchKeyword.isEmpty ? "暂无书源" : "未找到匹配书源",
                            systemImage: "network",
                            description: Text(
                                viewModel.state.searchKeyword.isEmpty ? "轻触右上角加号导入网络或本地书源" : "尝试更换搜索关键字"))
                            .padding(.top, 40)
                    } else {
                        sourcesListView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("书源")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: Binding(
                    get: { viewModel.state.searchKeyword },
                    set: { viewModel.send(.updateSearchKeyword($0)) }),
                prompt: "搜索书源名称或域名")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            if viewModel.state.isCheckingHealth {
                                Button {
                                    viewModel.send(.stopHealthCheck)
                                } label: {
                                    Label("停止体检", systemImage: "stop.circle")
                                }
                            } else {
                                Button {
                                    viewModel.send(.startHealthCheck)
                                } label: {
                                    Label("全源体检", systemImage: "waveform.path.ecg")
                                }
                            }

                            Divider()

                            Button {
                                viewModel.send(.disableInvalidSources)
                            } label: {
                                Label("禁用失效书源", systemImage: "eye.slash")
                            }

                            Button(role: .destructive) {
                                viewModel.send(.deleteInvalidSources)
                            } label: {
                                Label("清理失效书源", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .symbolRenderingMode(.hierarchical)
                        }

                        Button {
                            viewModel.send(.openImportSheet)
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .refreshable {
                viewModel.send(.loadSources)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .sheet(isPresented: Binding(
                get: { viewModel.state.isImportSheetPresented },
                set: {
                    if !$0 {
                        viewModel.send(.closeImportSheet)
                    }
                })) {
                    SourceImportSheet { text in
                        viewModel.send(.importFromText(text))
                    }
            }
            .sheet(item: Binding<BookSource?>(
                get: { viewModel.state.debuggingSource },
                set: {
                    if $0 == nil {
                        viewModel.send(.closeDebug)
                    }
                })) { source in
                    SourceDebugSheet(
                        source: source,
                        state: viewModel.state,
                        onIntent: { intent in
                            viewModel.send(intent)
                        })
            }
            .onAppear {
                viewModel.send(.loadSources)
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
                }
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background {
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                Color.black.opacity(0.55)
                            }
                        }
                        .clipShape(Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
                }
            }
        }
    }

    // MARK: - 书源卡片列表

    private var sourcesListView: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.state.filteredSources) { source in
                sourceCardView(source: source)
            }
        }
    }

    private func sourceCardView(source: BookSource) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(source.bookSourceName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let explore = source.exploreUrl, !explore.isEmpty {
                        Text("发现")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(source.bookSourceUrl)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 启用开关
            Toggle("", isOn: Binding(
                get: { source.enabled ?? true },
                set: { viewModel.send(.toggleSourceEnabled(sourceUrl: source.bookSourceUrl, enabled: $0)) }))
                .labelsHidden()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.send(.openDebug(source))
        }
        .contextMenu {
            Button {
                viewModel.send(.openDebug(source))
            } label: {
                Label("调试书源规则", systemImage: "ladybug")
            }

            Button(role: .destructive) {
                viewModel.send(.deleteSource(sourceUrl: source.bookSourceUrl))
            } label: {
                Label("删除书源", systemImage: "trash")
            }
        }
    }
}
