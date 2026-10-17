import Foundation

/// 搜索功能视图模型 (MVI 架构状态中枢)
@MainActor
public final class SearchViewModel: MVIViewModel<SearchState, SearchIntent, SearchEffect> {
    private let searchBooksUseCase: SearchBooksUseCase
    private let saveBookToShelfUseCase: SaveBookToShelfUseCase
    private let getBookshelfUseCase: GetBookshelfUseCase

    private var activeSearchTask: Task<Void, Never>?
    private let recentSearchesKey = "legado_recent_searches"

    public init(
        searchBooksUseCase: SearchBooksUseCase,
        saveBookToShelfUseCase: SaveBookToShelfUseCase,
        getBookshelfUseCase: GetBookshelfUseCase) {
        self.searchBooksUseCase = searchBooksUseCase
        self.saveBookToShelfUseCase = saveBookToShelfUseCase
        self.getBookshelfUseCase = getBookshelfUseCase

        let savedHistory = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
        super.init(initialState: SearchState(recentSearches: savedHistory))

        loadShelfBooks()
    }

    private func loadShelfBooks() {
        Task {
            if let books = try? await getBookshelfUseCase.execute() {
                let urls = Set(books.map(\.bookUrl))
                self.updateState { state in
                    state.addedBookUrls = urls
                }
            }
        }
    }

    override public func send(_ intent: SearchIntent) {
        switch intent {
        case let .updateQuery(newQuery):
            updateState { state in
                state.query = newQuery
                if newQuery.isEmpty {
                    state.resultGroups = []
                    state.isSearching = false
                    state.searchProgress = 0.0
                    state.progressText = ""
                }
            }

        case let .submitSearch(keyword):
            startSearch(keyword: keyword)

        case .cancelSearch:
            activeSearchTask?.cancel()
            activeSearchTask = nil
            updateState { state in
                state.isSearching = false
                state.progressText = "已取消搜索"
            }

        case let .selectKeyword(keyword):
            updateState { state in
                state.query = keyword
            }
            startSearch(keyword: keyword)

        case .clearRecentSearches:
            UserDefaults.standard.removeObject(forKey: recentSearchesKey)
            updateState { state in
                state.recentSearches = []
            }
            emitEffect(.hapticFeedback)

        case let .toggleExpandGroup(groupId):
            updateState { state in
                if state.expandedGroupIds.contains(groupId) {
                    state.expandedGroupIds.remove(groupId)
                } else {
                    state.expandedGroupIds.insert(groupId)
                }
            }
            emitEffect(.hapticFeedback)

        case let .addToBookshelf(result):
            Task {
                do {
                    try await saveBookToShelfUseCase.execute(from: result)
                    updateState { state in
                        state.addedBookUrls.insert(result.bookUrl)
                    }
                    emitEffect(.showToast("《\(result.name)》已加入书架"))
                    emitEffect(.hapticFeedback)
                } catch {
                    emitEffect(.showToast("加入书架失败: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func startSearch(keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 保存至搜索历史
        saveHistoryKeyword(trimmed)

        activeSearchTask?.cancel()
        activeSearchTask = Task {
            updateState { state in
                state.isSearching = true
                state.searchProgress = 0.0
                state.progressText = "正在准备书源..."
                state.resultGroups = []
                state.errorMessage = nil
            }

            var totalSources = 0
            var completedCount = 0

            let stream = searchBooksUseCase.execute(keyword: trimmed)
            for await event in stream {
                if Task.isCancelled {
                    break
                }

                switch event {
                case let .started(total):
                    totalSources = total
                    updateState { state in
                        state.progressText = "0 / \(total) 个书源已完成"
                    }

                case .sourceFinished, .sourceFailed:
                    completedCount += 1
                    let progress = totalSources > 0 ? Double(completedCount) / Double(totalSources) : 0.0
                    let text = "\(completedCount) / \(totalSources) 个书源已完成"
                    updateState { state in
                        state.searchProgress = progress
                        state.progressText = text
                    }

                case let .allCompleted(groups):
                    updateState { state in
                        state.isSearching = false
                        state.searchProgress = 1.0
                        state.resultGroups = groups
                        if groups.isEmpty {
                            state.progressText = "未找到相关书籍"
                        } else {
                            state.progressText = "共找到 \(groups.count) 本匹配书籍"
                        }
                    }
                }
            }
        }
    }

    private func saveHistoryKeyword(_ keyword: String) {
        var current = state.recentSearches
        current.removeAll { $0 == keyword }
        current.insert(keyword, at: 0)
        if current.count > 15 {
            current = Array(current.prefix(15))
        }
        UserDefaults.standard.set(current, forKey: recentSearchesKey)
        updateState { state in
            state.recentSearches = current
        }
    }
}
