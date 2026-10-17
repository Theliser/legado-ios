import Foundation

/// 书架业务视图模型
@MainActor
public final class BookshelfViewModel: BaseMVIViewModel<BookshelfState, BookshelfIntent, BookshelfEffect> {
    private let getBookshelfUseCase: GetBookshelfUseCase
    private let removeBookFromShelfUseCase: RemoveBookFromShelfUseCase
    private let checkBookUpdatesUseCase: CheckBookUpdatesUseCase

    public init(
        getBookshelfUseCase: GetBookshelfUseCase,
        removeBookFromShelfUseCase: RemoveBookFromShelfUseCase,
        checkBookUpdatesUseCase: CheckBookUpdatesUseCase) {
        self.getBookshelfUseCase = getBookshelfUseCase
        self.removeBookFromShelfUseCase = removeBookFromShelfUseCase
        self.checkBookUpdatesUseCase = checkBookUpdatesUseCase
        super.init(initialState: BookshelfState())

        send(.onAppear)
    }

    override public func send(_ intent: BookshelfIntent) {
        switch intent {
        case .onAppear:
            loadBooks()

        case .refresh:
            refreshUpdates()

        case let .selectGroup(group):
            updateState { $0.selectedGroup = group }
            emitEffect(.hapticFeedback)

        case let .didSelectBook(book):
            emitEffect(.navigateToReader(book))

        case let .openBookDetail(book):
            emitEffect(.navigateToDetail(book))

        case let .removeBook(bookUrl):
            deleteBook(bookUrl: bookUrl)
        }
    }

    private func loadBooks() {
        updateState { $0.isLoading = true }

        Task {
            do {
                let books = try await getBookshelfUseCase.execute()
                self.updateState { state in
                    state.isLoading = false
                    state.books = books
                }
            } catch {
                self.updateState { state in
                    state.isLoading = false
                }
                self.emitEffect(.showToast("获取书架失败: \(error.localizedDescription)"))
            }
        }
    }

    private func refreshUpdates() {
        updateState { $0.isLoading = true }

        Task {
            do {
                let updatedCount = try await checkBookUpdatesUseCase.execute()
                let books = try await getBookshelfUseCase.execute()
                self.updateState { state in
                    state.isLoading = false
                    state.books = books
                }
                if updatedCount > 0 {
                    self.emitEffect(.showToast("已更新 \(updatedCount) 本书的新章节"))
                } else {
                    self.emitEffect(.showToast("全部书籍均为最新"))
                }
                self.emitEffect(.hapticFeedback)
            } catch {
                self.updateState { state in
                    state.isLoading = false
                }
            }
        }
    }

    private func deleteBook(bookUrl: String) {
        Task {
            do {
                try await removeBookFromShelfUseCase.execute(bookUrl: bookUrl)
                let books = try await getBookshelfUseCase.execute()
                self.updateState { state in
                    state.books = books
                }
                self.emitEffect(.showToast("已从书架移出"))
                self.emitEffect(.hapticFeedback)
            } catch {
                self.emitEffect(.showToast("移除失败: \(error.localizedDescription)"))
            }
        }
    }
}
