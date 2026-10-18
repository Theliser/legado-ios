import Foundation

/// 换源业务状态中枢 (MVI ViewModel)
@MainActor
public final class ChangeSourceViewModel: BaseMVIViewModel<ChangeSourceState, ChangeSourceIntent, ChangeSourceEffect> {
    private let changeBookSourceUseCase: ChangeBookSourceUseCase
    private var searchTask: Task<Void, Never>?

    public init(
        book: Book,
        currentChapterTitle: String? = nil,
        currentChapterIndex: Int = 0,
        changeBookSourceUseCase: ChangeBookSourceUseCase) {
        self.changeBookSourceUseCase = changeBookSourceUseCase
        super.init(initialState: ChangeSourceState(
            book: book,
            currentChapterTitle: currentChapterTitle ?? book.durChapterTitle,
            currentChapterIndex: currentChapterIndex))

        send(.startSearch)
    }

    override public func send(_ intent: ChangeSourceIntent) {
        switch intent {
        case .startSearch:
            handleStartSearch()

        case let .selectCandidate(candidate):
            handleSelectCandidate(candidate)

        case .dismiss:
            emitEffect(.dismiss)
        }
    }

    private func handleStartSearch() {
        searchTask?.cancel()
        updateState {
            $0.isSearching = true
            $0.candidates = []
        }

        searchTask = Task {
            for await candidate in changeBookSourceUseCase.searchCandidates(for: state.book) {
                if Task.isCancelled {
                    break
                }
                self.updateState { state in
                    if !state.candidates.contains(where: { $0.id == candidate.id }) {
                        state.candidates.append(candidate)
                        // 排序：当前源置顶，其余按响应耗时递增升序
                        state.candidates.sort { first, second in
                            if first.isCurrent != second.isCurrent {
                                return first.isCurrent && !second.isCurrent
                            }
                            return first.elapsedMs < second.elapsedMs
                        }
                    }
                }
            }

            self.updateState { $0.isSearching = false }
        }
    }

    private func handleSelectCandidate(_ candidate: ChangeSourceCandidate) {
        if candidate.isCurrent {
            emitEffect(.showToast("当前已在此书源，无需切换"))
            return
        }

        updateState {
            $0.isSwitching = true
            $0.selectedCandidateId = candidate.id
        }
        emitEffect(.hapticFeedback)

        Task {
            do {
                let result = try await changeBookSourceUseCase.switchSource(
                    target: candidate,
                    currentBook: state.book,
                    currentChapterTitle: state.currentChapterTitle,
                    currentChapterIndex: state.currentChapterIndex)

                self.updateState {
                    $0.isSwitching = false
                    $0.book = result.updatedBook
                }

                self.emitEffect(.sourceSwitched(
                    updatedBook: result.updatedBook,
                    newToc: result.newToc,
                    matchedChapterIndex: result.matchedChapterIndex))
                self.emitEffect(.showToast("已成功换源至 [\(candidate.originName)]"))
                self.emitEffect(.dismiss)
            } catch {
                self.updateState {
                    $0.isSwitching = false
                    $0.selectedCandidateId = nil
                }
                self.emitEffect(.showToast("换源失败: \(error.localizedDescription)"))
            }
        }
    }
}
