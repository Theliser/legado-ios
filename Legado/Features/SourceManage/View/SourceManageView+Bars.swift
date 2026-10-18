import SwiftUI

extension SourceManageView {
    @ViewBuilder
    var groupFilterBar: some View {
        if !viewModel.state.availableGroups.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    groupPill(title: "全部", isSelected: viewModel.state.selectedGroup == "全部") {
                        viewModel.send(.selectGroup("全部"))
                    }

                    ForEach(viewModel.state.availableGroups, id: \.self) { group in
                        groupPill(title: group, isSelected: viewModel.state.selectedGroup == group) {
                            viewModel.send(.selectGroup(group))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func groupPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.thinMaterial.opacity(0.5)))
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 1.0 : 0.5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var healthCheckProgressBar: some View {
        if viewModel.state.isCheckingHealth, let progress = viewModel.state.healthCheckProgress {
            let progressFraction = Double(progress.completed) / Double(max(1, progress.total))
            HStack(spacing: 12) {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)

                Text("\(Int(progressFraction * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.send(.stopHealthCheck)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}
