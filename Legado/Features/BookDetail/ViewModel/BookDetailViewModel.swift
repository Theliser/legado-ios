import Foundation

/// 书籍详情视图模型 (MVI 架构状态中枢)
@MainActor
public final class BookDetailViewModel: BaseMVIViewModel<BookDetailState, BookDetailIntent, BookDetailEffect> {
    private let getBookDetailUseCase: GetBookDetailUseCase
    private let getBookTocUseCase: GetBookTocUseCase
    private let saveBookToShelfUseCase: SaveBookToShelfUseCase
    private let removeBookFromShelfUseCase: RemoveBookFromShelfUseCase
    private let bookRepository: BookRepository

    public init(
        book: Book,
        getBookDetailUseCase: GetBookDetailUseCase,
        getBookTocUseCase: GetBookTocUseCase,
        saveBookToShelfUseCase: SaveBookToShelfUseCase,
        removeBookFromShelfUseCase: RemoveBookFromShelfUseCase,
        bookRepository: BookRepository) {
        self.getBookDetailUseCase = getBookDetailUseCase
        self.getBookTocUseCase = getBookTocUseCase
        self.saveBookToShelfUseCase = saveBookToShelfUseCase
        self.removeBookFromShelfUseCase = removeBookFromShelfUseCase
        self.bookRepository = bookRepository

        super.init(initialState: BookDetailState(book: book))

        checkShelfStatus()
        send(.loadDetail)
    }

    private func checkShelfStatus() {
        Task {
            let existing = try? await bookRepository.getBook(by: state.book.bookUrl)
            let inShelf = existing != nil
            self.updateState { state in
                state.isInBookshelf = inShelf
            }
        }
    }

    override public func send(_ intent: BookDetailIntent) {
        switch intent {
        case .loadDetail:
            loadBookDetailAndToc()

        case .toggleBookshelf:
            toggleShelf()

        case .openToc:
            updateState { $0.isTocPresented = true }
            emitEffect(.hapticFeedback)

        case .closeToc:
            updateState { $0.isTocPresented = false }

        case .toggleTocReverse:
            updateState { $0.isReverseToc.toggle() }
            emitEffect(.hapticFeedback)

        case let .updateTocSearch(text):
            updateState { $0.tocSearchText = text }

        case let .selectChapter(chapter):
            updateState { $0.isTocPresented = false }
            emitEffect(.navigateToReader(chapterIndex: chapter.index))

        case .openSourceSwitch:
            updateState { $0.isSourceSwitchPresented = true }
            emitEffect(.hapticFeedback)

        case let .switchSource(newSource):
            handleSwitchSource(newSource)

        case let .updateBook(updatedBook, newToc):
            updateState {
                $0.book = updatedBook
                $0.chapters = newToc
            }
            checkShelfStatus()
        }
    }

    private func loadBookDetailAndToc() {
        updateState { $0.isLoading = true }

        Task {
            do {
                let updatedBook = try await getBookDetailUseCase.execute(book: state.book)
                let toc = try await getBookTocUseCase.execute(book: updatedBook, forceRefresh: true)

                self.updateState { state in
                    state.isLoading = false
                    state.book = updatedBook
                    state.chapters = toc
                }
            } catch {
                self.updateState { state in
                    state.isLoading = false
                    state.errorMessage = error.localizedDescription
                }
                self.emitEffect(.showToast("刷新详情失败: \(error.localizedDescription)"))
            }
        }
    }

    private func toggleShelf() {
        Task {
            do {
                if state.isInBookshelf {
                    try await removeBookFromShelfUseCase.execute(bookUrl: state.book.bookUrl)
                    updateState { state in
                        state.isInBookshelf = false
                    }
                    emitEffect(.showToast("已从书架移除"))
                } else {
                    try await saveBookToShelfUseCase.execute(state.book)
                    updateState { state in
                        state.isInBookshelf = true
                    }
                    emitEffect(.showToast("已成功加入书架"))
                }
                emitEffect(.hapticFeedback)
            } catch {
                emitEffect(.showToast("操作失败: \(error.localizedDescription)"))
            }
        }
    }

    private func handleSwitchSource(_ sourceItem: SearchResult) {
        var updated = state.book
        updated.bookUrl = sourceItem.bookUrl
        updated.origin = sourceItem.origin
        updated.originName = sourceItem.originName
        updated.tocUrl = sourceItem.tocUrl

        updateState { state in
            state.book = updated
            state.isSourceSwitchPresented = false
        }
        emitEffect(.showToast("已切换至书源: \(sourceItem.originName)"))
        send(.loadDetail)
    }
}
