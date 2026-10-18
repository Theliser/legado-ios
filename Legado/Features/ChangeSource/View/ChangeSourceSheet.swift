import SwiftUI

/// 液态玻璃一键换源半屏浮层 (Change Source Sheet)
public struct ChangeSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChangeSourceViewModel
    @State private var toastMessage: String?
    @State private var hapticTrigger = false

    private let onSwitched: ((Book, [Chapter], Int) -> Void)?

    public init(
        viewModel: ChangeSourceViewModel,
        onSwitched: ((Book, [Chapter], Int) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSwitched = onSwitched
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // 内容列表
                if viewModel.state.candidates.isEmpty, viewModel.state.isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在全网并发检索同名同作者书源...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.state.candidates.isEmpty {
                    ContentUnavailableView(
                        "未检索到其他书源",
                        systemImage: "books.vertical",
                        description: Text("请在书源管理中导入更多支持该书籍的书源"))
                } else {
                    candidateListView
                }

                // 悬浮 Toast 提示
                if let toastMessage {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.85))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("换源 (\(viewModel.state.candidates.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.state.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            viewModel.send(.startSearch)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationBackground(.ultraThinMaterial)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .onReceive(viewModel.effectPublisher) { effect in
            switch effect {
            case .dismiss:
                dismiss()

            case let .sourceSwitched(updatedBook, newToc, matchedIndex):
                onSwitched?(updatedBook, newToc, matchedIndex)

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
    }

    private var candidateListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.state.candidates) { candidate in
                    candidateCard(candidate)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func candidateCard(_ candidate: ChangeSourceCandidate) -> some View {
        Button {
            viewModel.send(.selectCandidate(candidate))
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    cardHeader(candidate)

                    if let latest = candidate.latestChapterTitle, !latest.isEmpty {
                        Text("最新：\(latest)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                cardStatusIcon(candidate)
            }
            .padding(14)
            .background(cardBackground(isCurrent: candidate.isCurrent))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func cardHeader(_ candidate: ChangeSourceCandidate) -> some View {
        HStack(spacing: 8) {
            Text(candidate.originName)
                .font(.headline)
                .foregroundStyle(.primary)

            if candidate.isCurrent {
                Text("当前源")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor.opacity(0.12)))
            }

            Spacer()

            HStack(spacing: 3) {
                Circle()
                    .fill(latencyColor(candidate.elapsedMs))
                    .frame(width: 6, height: 6)
                Text("\(candidate.elapsedMs)ms")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cardStatusIcon(_ candidate: ChangeSourceCandidate) -> some View {
        let isSelected = viewModel.state.selectedCandidateId == candidate.id
        if isSelected && viewModel.state.isSwitching {
            ProgressView()
                .controlSize(.regular)
        } else if candidate.isCurrent {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func cardBackground(isCurrent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isCurrent ? Color.accentColor.opacity(0.06) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isCurrent ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.15),
                        lineWidth: 0.5))
    }

    private func latencyColor(_ latencyMs: Int) -> Color {
        if latencyMs < 400 {
            return .green
        } else if latencyMs < 1000 {
            return .orange
        } else {
            return .red
        }
    }
}
