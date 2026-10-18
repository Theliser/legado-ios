import SwiftUI

/// 书源全能规则调试控制台（对齐 Legado Android：支持搜索/发现/详情/目录/正文多目标切换、示例直填与实时日志）
public struct SourceDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    let source: BookSource
    let state: SourceManageState
    let onIntent: (SourceManageIntent) -> Void

    public init(
        source: BookSource,
        state: SourceManageState,
        onIntent: @escaping (SourceManageIntent) -> Void) {
        self.source = source
        self.state = state
        self.onIntent = onIntent
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 1. 调试目标切换与控制面板
                debugControlsCard

                // 2. 日志分类过滤器
                filterSegmentedBar

                // 3. 控制台流式日志输出
                consoleTerminalView
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .navigationTitle("调试: \(source.bookSourceName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onIntent(.clearDebugLogs)
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                    }
                    .disabled(state.debugLogs.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(item: Binding<SourceDebugLog?>(
                get: { state.selectedPayloadLog },
                set: { onIntent(.selectPayloadLog($0)) })) { log in
                    SourceDebugPayloadSheet(log: log)
            }
        }
        .presentationDetents([.fraction(0.65), .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - 控制面板

    private var debugControlsCard: some View {
        VStack(spacing: 10) {
            // 目标选择器 (搜索 / 发现 / 详情 / 目录 / 正文)
            Picker("调试目标", selection: Binding(
                get: { state.debugTarget },
                set: { onIntent(.selectDebugTarget($0)) })) {
                    ForEach(SourceDebugTarget.allCases) { target in
                        Label(target.rawValue, systemImage: target.iconName)
                            .tag(target)
                    }
                }
                .pickerStyle(.segmented)

            // 输入栏与操作按钮
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: state.debugTarget.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        state.debugTarget.placeholder,
                        text: Binding(
                            get: { state.debugQuery },
                            set: { onIntent(.updateDebugQuery($0)) }))
                        .textFieldStyle(.plain)
                        .font(.subheadline)

                    if !state.debugQuery.isEmpty {
                        Button {
                            onIntent(.updateDebugQuery(""))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5))

                Button {
                    if state.isDebugging {
                        onIntent(.stopDebug)
                    } else {
                        onIntent(.startDebug)
                    }
                } label: {
                    HStack(spacing: 4) {
                        if state.isDebugging {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("停止")
                        } else {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                            Text("开始")
                        }
                    }
                }
                .buttonStyle(.glassProminent(tint: state.isDebugging ? .red : .accentColor, cornerRadius: 10))
                .disabled(state.debugQuery.isEmpty && !state.isDebugging)
            }

            // 快捷预设示例标签
            if !state.debugExamples.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("示例:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        ForEach(state.debugExamples) { example in
                            Button {
                                onIntent(.useDebugExample(example))
                            } label: {
                                HStack(spacing: 4) {
                                    Text(example.title)
                                    Text("(\(example.target.rawValue))")
                                        .font(.caption2)
                                        .opacity(0.7)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    state.debugTarget == example.target && state.debugQuery == example.value
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(uiColor: .tertiarySystemFill))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - 过滤器栏

    private var filterSegmentedBar: some View {
        HStack {
            Picker("过滤器", selection: Binding(
                get: { state.debugFilter },
                set: { onIntent(.selectDebugFilter($0)) })) {
                    ForEach(SourceDebugFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

            Spacer()

            if let report = state.debugReport {
                HStack(spacing: 4) {
                    Image(systemName: report.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(report.isSuccess ? .green : .red)
                    Text("\(report.durationMs)ms")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - 控制台视图

    private var consoleTerminalView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if state.filteredDebugLogs.isEmpty {
                        emptyConsoleView
                    } else {
                        ForEach(state.filteredDebugLogs) { log in
                            logEntryRow(log: log)
                                .id(log.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.black.opacity(0.65)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.5))
            .onChange(of: state.debugLogs.count) {
                if let lastId = state.filteredDebugLogs.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyConsoleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(state.isDebugging ? "正在调度并接收书源调试流..." : "点击开始或示例运行规则测试")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func logEntryRow(log: SourceDebugLog) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(log.timeFormatted)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("[\(log.level.rawValue)]")
                .font(.caption2.monospaced().bold())
                .foregroundStyle(colorForLogLevel(log.level))

            Text(log.message)
                .font(.caption2.monospaced())
                .foregroundStyle(.white)

            Spacer()

            if log.payload != nil {
                Button {
                    onIntent(.selectPayloadLog(log))
                } label: {
                    Text("查看数据")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func colorForLogLevel(_ level: SourceDebugLog.LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .payload: return .cyan
        }
    }
}

/// 数据载荷查看抽屉
public struct SourceDebugPayloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let log: SourceDebugLog

    @State private var copied = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                Text(log.payload ?? log.message)
                    .font(.footnote.monospaced())
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(log.message)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        UIPasteboard.general.string = log.payload ?? log.message
                        copied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            copied = false
                        }
                    } label: {
                        Label(copied ? "已复制" : "复制", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
