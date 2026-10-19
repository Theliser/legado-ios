import SwiftUI
import UIKit

/// 书源全能可视化编辑工作台（遵循 MVI 架构与 iOS 原生 Liquid Glass 美学）
public struct BookSourceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: BookSourceEditViewModel

    private let onDismissCallback: (() -> Void)?
    private let onOpenDebugCallback: ((BookSource) -> Void)?

    @State private var toastMessage: String?
    @State private var hapticTrigger = false

    public init(
        source: BookSource? = nil,
        onDismiss: (() -> Void)? = nil,
        onOpenDebug: ((BookSource) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: BookSourceEditViewModel(source: source))
        self.onDismissCallback = onDismiss
        self.onOpenDebugCallback = onOpenDebug
    }

    public init(viewModel: BookSourceEditViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onDismissCallback = nil
        self.onOpenDebugCallback = nil
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.state.isJsonEditorPresented {
                    jsonEditorView
                } else {
                    tabHeaderView
                    formContentView
                }

                // 底部快速语法助手胶囊栏
                if !viewModel.state.isJsonEditorPresented {
                    BookSourceSyntaxChipsBar { token in
                        viewModel.send(.insertSyntaxChip(token: token))
                    }
                }
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        viewModel.send(.requestDismiss)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // 切换 JSON / 表单模式
                        Button {
                            viewModel.send(.toggleJsonMode)
                        } label: {
                            let icon = viewModel.state.isJsonEditorPresented
                                ? "list.bullet.rectangle" : "curlybraces"
                            Image(systemName: icon)
                                .font(.subheadline)
                        }

                        // 调试入口
                        Button {
                            viewModel.send(.openDebug)
                        } label: {
                            Image(systemName: "ladybug")
                                .font(.subheadline)
                        }

                        // 保存按钮
                        Button("保存") {
                            viewModel.send(.save)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.state.canSave)

                        // 更多功能菜单
                        Menu {
                            Button {
                                viewModel.send(.saveAndDebug)
                            } label: {
                                Label("保存并调试", systemImage: "play.circle")
                            }

                            Divider()

                            Button {
                                UIPasteboard.general.string = viewModel.state.rawJsonText
                                viewModel.send(.clearError)
                                toastMessage = "书源 JSON 已复制到剪贴板"
                            } label: {
                                Label("复制 JSON", systemImage: "doc.on.doc")
                            }

                            Button {
                                if let text = UIPasteboard.general.string, !text.isEmpty {
                                    viewModel.send(.importJsonFromText(text))
                                } else {
                                    toastMessage = "剪贴板为空"
                                }
                            } label: {
                                Label("从剪贴板粘贴", systemImage: "document.on.clipboard")
                            }

                            if viewModel.state.isJsonEditorPresented {
                                Button {
                                    viewModel.send(.formatJson)
                                } label: {
                                    Label("格式化 JSON", systemImage: "wand.and.stars")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .alert("放弃修改？", isPresented: Binding(
                get: { viewModel.state.isDiscardAlertPresented },
                set: {
                    if !$0 {
                        viewModel.send(.cancelDiscard)
                    }
                })) {
                    Button("继续编辑", role: .cancel) {
                        viewModel.send(.cancelDiscard)
                    }
                    Button("放弃修改", role: .destructive) {
                        viewModel.send(.confirmDiscard)
                    }
            } message: {
                Text("当前书源有未保存的改动，放弃后修改将丢失。")
            }
            .onReceive(viewModel.effectPublisher) { effect in
                handleEffect(effect)
            }
            .overlay(alignment: .bottom) {
                toastOverlay
            }
        }
    }

    // MARK: - 标签页顶栏

    private var tabHeaderView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BookSourceEditTab.allCases) { tab in
                    let isSelected = viewModel.state.selectedTab == tab
                    Button {
                        viewModel.send(.selectTab(tab))
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.footnote)
                            Text(tab.rawValue)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if isSelected {
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.18))
                            } else {
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    isSelected ? Color.accentColor : Color.white.opacity(0.2),
                                    lineWidth: isSelected ? 1 : 0.5))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var editorTitle: String {
        if viewModel.state.isNewSource {
            return "新建书源"
        }
        let name = viewModel.state.source.bookSourceName
        return "编辑: \(name.isEmpty ? "未命名" : name)"
    }

    // MARK: - 表单内容容器

    private var formContentView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let error = viewModel.state.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            viewModel.send(.clearError)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.bottom, 4)
                }

                switch viewModel.state.selectedTab {
                case .base:
                    baseSection

                case .search:
                    searchSection

                case .explore:
                    exploreSection

                case .info:
                    infoSection

                case .toc:
                    tocSection

                case .content:
                    contentSection

                case .review:
                    reviewSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - 源码编辑视图

    private var jsonEditorView: some View {
        VStack(spacing: 8) {
            HStack {
                Label("JSON 源码编辑模式", systemImage: "curlybraces")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("格式化") {
                    viewModel.send(.formatJson)
                }
                .font(.footnote)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            TextEditor(text: Binding(
                get: { viewModel.state.rawJsonText },
                set: { viewModel.send(.updateRawJson($0)) }))
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    // MARK: - 副作用处理

    private func handleEffect(_ effect: BookSourceEditEffect) {
        switch effect {
        case .dismiss:
            if let onDismissCallback {
                onDismissCallback()
            } else {
                dismiss()
            }

        case let .openDebug(source):
            if let onOpenDebugCallback {
                onOpenDebugCallback(source)
            } else {
                dismiss()
            }

        case let .savedSuccessfully(source):
            toastMessage = "已保存: \(source.bookSourceName)"

        case let .showToast(message):
            toastMessage = message
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if toastMessage == message {
                    toastMessage = nil
                }
            }

        case .hapticFeedback:
            hapticTrigger.toggle()

        case let .copyToClipboard(text):
            UIPasteboard.general.string = text
            toastMessage = "已复制到剪贴板"
        }
    }

    // MARK: - 浮动 Toast 气泡

    @ViewBuilder
    private var toastOverlay: some View {
        if let toastMessage {
            Text(toastMessage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.black.opacity(0.6)
                    }
                }
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
        }
    }
}
