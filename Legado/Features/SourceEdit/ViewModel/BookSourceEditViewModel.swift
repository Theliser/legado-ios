import Factory
import Foundation

/// 书源编辑页面 ViewModel（遵循严格 MVI 架构与 @MainActor 标注）
@MainActor
public final class BookSourceEditViewModel:
    MVIViewModel<BookSourceEditState, BookSourceEditIntent, BookSourceEditEffect> {
    @Injected(\.saveBookSourceUseCase) private var saveBookSourceUseCase: SaveBookSourceUseCase

    public init(
        source: BookSource? = nil,
        saveUseCase: SaveBookSourceUseCase? = nil) {
        let initialSource = source ?? BookSource(bookSourceUrl: "", bookSourceName: "")
        let initialJson = Self.encodeSourceToPrettyJson(initialSource)
        let initialState = BookSourceEditState(
            source: initialSource,
            originalSource: source,
            selectedTab: .base,
            isJsonEditorPresented: false,
            rawJsonText: initialJson,
            isDirty: false,
            isLoading: false,
            isSaving: false)
        super.init(initialState: initialState)

        if let saveUseCase {
            self.saveBookSourceUseCase = saveUseCase
        }
    }

    override public func send(_ intent: BookSourceEditIntent) {
        if handleFormIntent(intent) {
            return
        }
        if handleFileOrJsonIntent(intent) {
            return
        }
        handleActionIntent(intent)
    }

    private func handleFormIntent(_ intent: BookSourceEditIntent) -> Bool {
        switch intent {
        case let .loadSource(source):
            handleLoadSource(source)

        case let .selectTab(tab):
            updateState { $0.selectedTab = tab }

        case let .updateField(key, value):
            handleUpdateField(key: key, value: value)

        case let .setActiveField(key):
            updateState { $0.activeFieldKey = key }

        case let .insertSyntaxChip(token):
            handleInsertSyntaxChip(token)

        case let .toggleBoolean(key, value):
            handleToggleBoolean(key: key, value: value)

        case let .updateSourceType(typeIndex):
            updateState {
                $0.source.bookSourceType = typeIndex
                $0.isDirty = true
            }

        default:
            return false
        }
        return true
    }

    private func handleFileOrJsonIntent(_ intent: BookSourceEditIntent) -> Bool {
        switch intent {
        case .toggleJsonMode:
            handleToggleJsonMode()

        case let .updateRawJson(text):
            updateState {
                $0.rawJsonText = text
                $0.isDirty = true
            }

        case .formatJson:
            handleFormatJson()

        case let .importJsonFromText(text):
            handleImportJson(text)

        default:
            return false
        }
        return true
    }

    private func handleActionIntent(_ intent: BookSourceEditIntent) {
        switch intent {
        case .save:
            handleSave(thenOpenDebug: false)

        case .saveAndDebug:
            handleSave(thenOpenDebug: true)

        case .openDebug:
            updateState { $0.isDebuggingPresented = true }

        case .closeDebug:
            updateState { $0.isDebuggingPresented = false }

        case .requestDismiss:
            handleRequestDismiss()

        case .confirmDiscard:
            updateState { $0.isDiscardAlertPresented = false }
            emitEffect(.dismiss)

        case .cancelDiscard:
            updateState { $0.isDiscardAlertPresented = false }

        case .clearError:
            updateState { $0.errorMessage = nil }

        default:
            break
        }
    }

    private func handleRequestDismiss() {
        if state.isDirty {
            updateState { $0.isDiscardAlertPresented = true }
        } else {
            emitEffect(.dismiss)
        }
    }

    // MARK: - 业务逻辑与状态派发

    private func handleLoadSource(_ source: BookSource?) {
        let loaded = source ?? BookSource(bookSourceUrl: "", bookSourceName: "")
        let json = Self.encodeSourceToPrettyJson(loaded)
        updateState {
            $0.source = loaded
            $0.originalSource = source
            $0.rawJsonText = json
            $0.isDirty = false
            $0.isLoading = false
            $0.errorMessage = nil
        }
    }

    private func handleToggleJsonMode() {
        if state.isJsonEditorPresented {
            // 试图从 JSON 切回表单模式：尝试反序列化
            do {
                let parsed = try Self.decodeSourceFromJson(state.rawJsonText)
                updateState {
                    $0.source = parsed
                    $0.isJsonEditorPresented = false
                    $0.errorMessage = nil
                }
                emitEffect(.hapticFeedback)
            } catch {
                updateState {
                    $0.errorMessage = "JSON 语法解析失败，请检查格式后再切换: \(error.localizedDescription)"
                }
                emitEffect(.showToast("JSON 语法有误"))
            }
        } else {
            // 从表单切到 JSON 模式：序列化最新数据
            let json = Self.encodeSourceToPrettyJson(state.source)
            updateState {
                $0.rawJsonText = json
                $0.isJsonEditorPresented = true
            }
            emitEffect(.hapticFeedback)
        }
    }

    private func handleFormatJson() {
        guard let data = state.rawJsonText.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                  withJSONObject: jsonObject,
                  options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            emitEffect(.showToast("无法格式化：JSON 语法错误"))
            return
        }
        updateState {
            $0.rawJsonText = prettyString
            $0.isDirty = true
        }
        emitEffect(.hapticFeedback)
    }

    private func handleImportJson(_ text: String) {
        do {
            let parsed = try Self.decodeSourceFromJson(text)
            let formattedJson = Self.encodeSourceToPrettyJson(parsed)
            updateState {
                $0.source = parsed
                $0.rawJsonText = formattedJson
                $0.isDirty = true
                $0.errorMessage = nil
            }
            emitEffect(.showToast("已成功载入书源配置"))
            emitEffect(.hapticFeedback)
        } catch {
            updateState {
                $0.errorMessage = "导入失败: \(error.localizedDescription)"
            }
            emitEffect(.showToast("导入失败，格式不匹配"))
        }
    }

    private func handleSave(thenOpenDebug: Bool) {
        if state.isJsonEditorPresented {
            // 先尝试同步 JSON 至当前对象
            do {
                let parsed = try Self.decodeSourceFromJson(state.rawJsonText)
                updateState { $0.source = parsed }
            } catch {
                updateState { $0.errorMessage = "请先修正 JSON 语法错误: \(error.localizedDescription)" }
                emitEffect(.showToast("JSON 格式错误，无法保存"))
                return
            }
        }

        if let validationMsg = state.validationError {
            updateState { $0.errorMessage = validationMsg }
            emitEffect(.showToast(validationMsg))
            return
        }

        updateState {
            $0.isSaving = true
            $0.errorMessage = nil
        }

        let sourceToSave = state.source
        let originalUrl = state.originalSource?.bookSourceUrl

        Task {
            do {
                try await saveBookSourceUseCase.execute(source: sourceToSave, originalUrl: originalUrl)
                updateState {
                    $0.isSaving = false
                    $0.isDirty = false
                    $0.originalSource = sourceToSave
                }
                emitEffect(.savedSuccessfully(sourceToSave))
                emitEffect(.showToast("书源保存成功"))
                emitEffect(.hapticFeedback)

                if thenOpenDebug {
                    emitEffect(.openDebug(sourceToSave))
                } else {
                    emitEffect(.dismiss)
                }
            } catch {
                updateState {
                    $0.isSaving = false
                    $0.errorMessage = "保存失败: \(error.localizedDescription)"
                }
                emitEffect(.showToast("保存失败: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - 辅助 JSON 转换

    public static func encodeSourceToPrettyJson(_ source: BookSource) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(source), let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    public static func decodeSourceFromJson(_ text: String) throws -> BookSource {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw BookSourceEditError.invalidJson("编码格式错误")
        }

        let decoder = JSONDecoder()
        if trimmed.hasPrefix("[") {
            let sources = try decoder.decode([BookSource].self, from: data)
            guard let first = sources.first else {
                throw BookSourceEditError.invalidJson("JSON 数组内无有效书源对象")
            }
            return first
        } else {
            return try decoder.decode(BookSource.self, from: data)
        }
    }
}
