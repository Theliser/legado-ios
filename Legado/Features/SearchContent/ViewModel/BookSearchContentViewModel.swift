import Foundation

/// 正文全文搜索状态中枢 (MVI ViewModel)
@MainActor
public final class BookSearchContentViewModel:
    BaseMVIViewModel<BookSearchContentState, BookSearchContentIntent, BookSearchContentEffect> {
    private let book: Book
    private let chapters: [Chapter]
    private let getChapterContentUseCase: GetChapterContentUseCase
    private let searchUseCase: SearchBookContentUseCase
    private var searchTask: Task<Void, Never>?

    public init(
        book: Book,
        chapters: [Chapter],
        getChapterContentUseCase: GetChapterContentUseCase,
        searchUseCase: SearchBookContentUseCase = SearchBookContentUseCase()) {
        self.book = book
        self.chapters = chapters
        self.getChapterContentUseCase = getChapterContentUseCase
        self.searchUseCase = searchUseCase
        super.init(initialState: BookSearchContentState())
    }

    override public func send(_ intent: BookSearchContentIntent) {
        switch intent {
        case let .updateQuery(text):
            updateState { $0.query = text }
            debounceSearch(text)

        case .search:
            performSearch(state.query)

        case let .selectMatch(match):
            emitEffect(.hapticFeedback)
            emitEffect(.jumpToChapter(chapterIndex: match.chapterIndex, matchOffset: match.matchOffset))
            emitEffect(.dismiss)

        case .clear:
            searchTask?.cancel()
            updateState {
                $0.query = ""
                $0.matches = []
                $0.isSearching = false
            }
        }
    }

    private func debounceSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else {
            updateState {
                $0.matches = []
                $0.isSearching = false
            }
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled {
                return
            }
            self.performSearch(trimmed)
        }
    }

    private func performSearch(_ keyword: String) {
        searchTask?.cancel()
        updateState {
            $0.isSearching = true
            $0.matches = []
        }

        searchTask = Task {
            for await match in searchUseCase.search(
                keyword: keyword,
                book: book,
                chapters: chapters,
                getChapterContentUseCase: getChapterContentUseCase) {
                if Task.isCancelled {
                    break
                }
                self.updateState { state in
                    state.matches.append(match)
                }
            }

            self.updateState { $0.isSearching = false }
        }
    }
}
