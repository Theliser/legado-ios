import SwiftUI

/// 书源实时规则调试抽屉
public struct SourceDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: BookSource
    let report: SourceDebugReport?
    let isDebugging: Bool
    let onRunDebug: (String) -> Void

    @State private var keyword: String

    public init(
        source: BookSource,
        report: SourceDebugReport?,
        isDebugging: Bool,
        onRunDebug: @escaping (String) -> Void) {
        self.source = source
        self.report = report
        self.isDebugging = isDebugging
        self.onRunDebug = onRunDebug
        let defaultKeyword = source.ruleSearch?.checkKeyWord ?? "宿命"
        _keyword = State(initialValue: defaultKeyword.isEmpty ? "宿命" : defaultKeyword)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                // 测试输入栏
                HStack(spacing: 10) {
                    TextField("测试搜索关键字", text: $keyword)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        onRunDebug(keyword)
                    } label: {
                        if isDebugging {
                            ProgressView()
                                .padding(.horizontal, 12)
                        } else {
                            Text("开始调试")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .disabled(isDebugging || keyword.isEmpty)
                }

                // 调试控制台输出窗口
                consoleTerminalView

                Spacer()
            }
            .padding(16)
            .navigationTitle("调试: \(source.bookSourceName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if report == nil, !isDebugging {
                    onRunDebug(keyword)
                }
            }
        }
        .presentationDetents([.fraction(0.55), .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - 控制台视图

    private var consoleTerminalView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let report {
                    HStack {
                        Label(
                            report.isSuccess ? "诊断通过" : "诊断未通过",
                            systemImage: report.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(report.isSuccess ? .green : .red)

                        Spacer()

                        Text("耗时: \(report.durationMs)ms")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider().opacity(0.3)
                }

                if let logs = report?.logs, !logs.isEmpty {
                    ForEach(logs) { log in
                        HStack(alignment: .top, spacing: 6) {
                            Text("[\(log.level.rawValue)]")
                                .font(.caption2.monospaced().bold())
                                .foregroundStyle(colorForLogLevel(log.level))

                            Text(log.message)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.primary)
                        }
                    }
                } else if isDebugging {
                    HStack {
                        ProgressView()
                        Text("正在向源站发起请求并执行规则调度...")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                } else {
                    Text("点击右上角开始调试以运行规则诊断。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }

    private func colorForLogLevel(_ level: SourceDebugLog.LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}
