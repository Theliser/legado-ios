import Foundation

/// 书源管理视图模型 (MVI 架构状态中枢)
@MainActor
public final class SourceManageViewModel: BaseMVIViewModel<SourceManageState, SourceManageIntent, SourceManageEffect> {
    private let sourceRepository: BookSourceRepository
    private let toggleEnabledUseCase: ToggleBookSourceEnabledUseCase
    private let deleteSourceUseCase: DeleteBookSourceUseCase
    private let importSourcesUseCase: ImportBookSourcesUseCase
    private let debugSourceUseCase: DebugBookSourceUseCase

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

        case .openDebug, .closeDebug, .runDebug:
            handleDebugIntent(intent)
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

    private func handleDebugIntent(_ intent: SourceManageIntent) {
        switch intent {
        case let .openDebug(source):
            updateState {
                $0.debuggingSource = source
                $0.debugReport = nil
            }
            emitEffect(.hapticFeedback)

        case .closeDebug:
            updateState {
                $0.debuggingSource = nil
                $0.debugReport = nil
            }

        case let .runDebug(source, keyword):
            executeDebug(source: source, keyword: keyword)

        default:
            break
        }
    }

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
                self.emitEffect(.showToast("更新状态失败: \(error.localizedDescription)"))
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

    private func executeDebug(source: BookSource, keyword: String) {
        updateState { $0.isDebugging = true }

        Task {
            let report = await debugSourceUseCase.execute(source: source, keyword: keyword)
            self.updateState {
                $0.isDebugging = false
                $0.debugReport = report
            }
            self.emitEffect(.hapticFeedback)
        }
    }
}
