import Foundation

/// 书源管理视图模型 (MVI 架构状态中枢)
@MainActor
public final class SourceManageViewModel: BaseMVIViewModel<SourceManageState, SourceManageIntent, SourceManageEffect> {
    private let sourceRepository: BookSourceRepository
    private let toggleEnabledUseCase: ToggleBookSourceEnabledUseCase
    private let deleteSourceUseCase: DeleteBookSourceUseCase
    private let importSourcesUseCase: ImportBookSourcesUseCase
    private let debugSourceUseCase: DebugBookSourceUseCase

    private var debugTask: Task<Void, Never>?

    public init(
        sourceRepository: BookSourceRepository,
        toggleEnabledUseCase: ToggleBookSourceEnabledUseCase,
        deleteSourceUseCase: DeleteBookSourceUseCase,
        importSourcesUseCase: ImportBookSourcesUseCase,
        debugSourceUseCase: DebugBookSourceUseCase) {
        self.sourceRepository = sourceRepository
        self.toggleEnabledUseCase = toggleEnabledUseCase
        self.deleteSourceUseCase = deleteSourceUseCase
        self.importSourcesUseCase = importSourcesUseCase
        self.debugSourceUseCase = debugSourceUseCase
        super.init(initialState: SourceManageState())

        send(.loadSources)
    }

    override public func send(_ intent: SourceManageIntent) {
        switch intent {
        case .loadSources, .updateSearchKeyword, .toggleSourceEnabled, .deleteSource:
            handleDataIntent(intent)

        case .openImportSheet, .closeImportSheet, .importFromText:
            handleSheetIntent(intent)

        case .openDebug, .closeDebug, .selectDebugTarget, .updateDebugQuery,
             .selectDebugFilter, .useDebugExample:
            handleDebugConfigIntent(intent)

        case .startDebug, .stopDebug, .clearDebugLogs, .selectPayloadLog, .runDebug:
            handleDebugActionIntent(intent)
        }
    }

    private func handleDataIntent(_ intent: SourceManageIntent) {
        switch intent {
        case .loadSources:
            loadAllSources()

        case let .updateSearchKeyword(keyword):
            updateState { $0.searchKeyword = keyword }

        case let .toggleSourceEnabled(sourceUrl, enabled):
            toggleEnabled(sourceUrl: sourceUrl, enabled: enabled)

        case let .deleteSource(sourceUrl):
            deleteSource(sourceUrl: sourceUrl)

        default:
            break
        }
    }

    private func handleSheetIntent(_ intent: SourceManageIntent) {
        switch intent {
        case .openImportSheet:
            updateState { $0.isImportSheetPresented = true }
            emitEffect(.hapticFeedback)

        case .closeImportSheet:
            updateState { $0.isImportSheetPresented = false }

        case let .importFromText(text):
            importSources(text: text)

        default:
            break
        }
    }

    private func handleDebugConfigIntent(_ intent: SourceManageIntent) {
        switch intent {
        case let .openDebug(source):
            openDebugConsole(source: source)

        case .closeDebug:
            closeDebugConsole()

        case let .selectDebugTarget(target):
            switchDebugTarget(target)

        case let .updateDebugQuery(query):
            updateState { $0.debugQuery = query }

        case let .selectDebugFilter(filter):
            updateState { $0.debugFilter = filter }

        case let .useDebugExample(example):
            updateState {
                $0.debugTarget = example.target
                $0.debugQuery = example.value
            }

        default:
            break
        }
    }

    private func handleDebugActionIntent(_ intent: SourceManageIntent) {
        switch intent {
        case .startDebug:
            startDebugExecution()

        case .stopDebug:
            stopDebugExecution()

        case .clearDebugLogs:
            updateState {
                $0.debugLogs = []
                $0.debugReport = nil
            }

        case let .selectPayloadLog(log):
            updateState { $0.selectedPayloadLog = log }

        case let .runDebug(source, keyword):
            updateState {
                $0.debuggingSource = source
                $0.debugQuery = keyword
                $0.debugTarget = .search
            }
            startDebugExecution()

        default:
            break
        }
    }

    // MARK: - 书源列表数据操作

    private func loadAllSources() {
        updateState { $0.isLoading = true }

        Task {
            do {
                let list = try await sourceRepository.fetchSources()
                self.updateState { state in
                    state.isLoading = false
                    state.sources = list
                }
            } catch {
                self.updateState { state in
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                }
                self.emitEffect(.showToast("加载书源失败: \(error.localizedDescription)"))
            }
        }
    }

    private func toggleEnabled(sourceUrl: String, enabled: Bool) {
        Task {
            do {
                try await toggleEnabledUseCase.execute(sourceUrl: sourceUrl, enabled: enabled)
                self.loadAllSources()
                self.emitEffect(.hapticFeedback)
            } catch {
                self.emitEffect(.showToast("更新书源状态失败: \(error.localizedDescription)"))
            }
        }
    }

    private func deleteSource(sourceUrl: String) {
        Task {
            do {
                try await deleteSourceUseCase.execute(sourceUrl: sourceUrl)
                self.loadAllSources()
                self.emitEffect(.showToast("已成功删除书源"))
                self.emitEffect(.hapticFeedback)
            } catch {
                self.emitEffect(.showToast("删除书源失败: \(error.localizedDescription)"))
            }
        }
    }

    private func importSources(text: String) {
        updateState { $0.isLoading = true }

        Task {
            do {
                let count = try await importSourcesUseCase.execute(input: text)
                self.updateState {
                    $0.isLoading = false
                    $0.isImportSheetPresented = false
                }
                self.loadAllSources()
                self.emitEffect(.showToast("成功导入 \(count) 个书源"))
                self.emitEffect(.hapticFeedback)
            } catch {
                self.updateState { $0.isLoading = false }
                self.emitEffect(.showToast("导入失败: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - 书源调试逻辑

    private func openDebugConsole(source: BookSource) {
        let examples = debugSourceUseCase.generateExamples(for: source)
        let defaultQuery = examples.first?.value ?? "斗罗大陆"

        updateState {
            $0.debuggingSource = source
            $0.debugReport = nil
            $0.debugLogs = []
            $0.debugExamples = examples
            $0.debugTarget = .search
            $0.debugQuery = defaultQuery
            $0.debugFilter = .all
        }
        emitEffect(.hapticFeedback)
    }

    private func closeDebugConsole() {
        debugTask?.cancel()
        debugTask = nil
        updateState {
            $0.isDebugging = false
            $0.debuggingSource = nil
            $0.debugReport = nil
            $0.debugLogs = []
        }
    }

    private func switchDebugTarget(_ target: SourceDebugTarget) {
        updateState { state in
            state.debugTarget = target
            if let matchingExample = state.debugExamples.first(where: { $0.target == target }) {
                state.debugQuery = matchingExample.value
            }
        }
    }

    private func startDebugExecution() {
        guard let source = state.debuggingSource else { return }
        let target = state.debugTarget
        let query = state.debugQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            emitEffect(.showToast("调试内容不能为空"))
            return
        }

        debugTask?.cancel()
        updateState {
            $0.isDebugging = true
            $0.debugLogs = []
            $0.debugReport = nil
        }
        emitEffect(.hapticFeedback)

        debugTask = Task {
            let report = await debugSourceUseCase.execute(
                source: source,
                target: target,
                query: query,
                onLog: { [weak self] newLog in
                    Task { @MainActor [weak self] in
                        self?.updateState { $0.debugLogs.append(newLog) }
                    }
                })

            guard !Task.isCancelled else { return }
            self.updateState {
                $0.isDebugging = false
                $0.debugReport = report
            }
            self.emitEffect(.hapticFeedback)
        }
    }

    private func stopDebugExecution() {
        debugTask?.cancel()
        debugTask = nil
        updateState {
            $0.isDebugging = false
            $0.debugLogs.append(SourceDebugLog(
                level: .warning,
                message: "⏹️ 用户手动终止调试",
                elapsedMs: 0))
        }
        emitEffect(.hapticFeedback)
    }
}
