import Foundation

/// 书架业务视图模型 (MVI 架构)
@MainActor
public final class BookshelfViewModel: BaseMVIViewModel<BookshelfState, BookshelfIntent, BookshelfEffect> {
    private let getBookshelfUseCase: GetBookshelfUseCase
    private let removeBookFromShelfUseCase: RemoveBookFromShelfUseCase
    private let checkBookUpdatesUseCase: CheckBookUpdatesUseCase
    private let saveBookToShelfUseCase: SaveBookToShelfUseCase?
    private let getBookGroupsUseCase: GetBookGroupsUseCase?
    private let saveBookGroupUseCase: SaveBookGroupUseCase?
    private let deleteBookGroupUseCase: DeleteBookGroupUseCase?

    public init(
        getBookshelfUseCase: GetBookshelfUseCase,
        removeBookFromShelfUseCase: RemoveBookFromShelfUseCase,
        checkBookUpdatesUseCase: CheckBookUpdatesUseCase,
        saveBookToShelfUseCase: SaveBookToShelfUseCase? = nil,
        getBookGroupsUseCase: GetBookGroupsUseCase? = nil,
        saveBookGroupUseCase: SaveBookGroupUseCase? = nil,
        deleteBookGroupUseCase: DeleteBookGroupUseCase? = nil) {
        self.getBookshelfUseCase = getBookshelfUseCase
        self.removeBookFromShelfUseCase = removeBookFromShelfUseCase
        self.checkBookUpdatesUseCase = checkBookUpdatesUseCase
        self.saveBookToShelfUseCase = saveBookToShelfUseCase
        self.getBookGroupsUseCase = getBookGroupsUseCase
        self.saveBookGroupUseCase = saveBookGroupUseCase
        self.deleteBookGroupUseCase = deleteBookGroupUseCase
        super.init(initialState: BookshelfState())

        send(.onAppear)
    }

    override public func send(_ intent: BookshelfIntent) {
        switch intent {
        case .onAppear:
            loadData()

        case .refresh, .refreshAllBookUpdates:
            refreshUpdates()

        case let .updateSearchText(query):
            updateState { $0.searchText = query }

        case let .selectGroup(group):
            updateState { $0.selectedGroup = group }
            emitEffect(.hapticFeedback)

        case .toggleLayoutMode:
            updateState { $0.layoutMode = ($0.layoutMode == .grid ? .list : .grid) }
            emitEffect(.hapticFeedback)

        case .didSelectBook, .openBookDetail, .removeBook:
            handleBookActionIntent(intent)

        case .toggleBatchMode, .toggleSelectBook, .selectAll, .deselectAll,
             .batchRemoveSelected, .batchMoveSelectedToGroup:
            handleBatchIntent(intent)

        case .addCustomGroup, .deleteCustomGroup, .moveBookToGroup:
            handleGroupIntent(intent)
        }
    }

    private func handleBookActionIntent(_ intent: BookshelfIntent) {
        switch intent {
        case let .didSelectBook(book):
            if state.isBatchMode {
                send(.toggleSelectBook(bookUrl: book.bookUrl))
            } else {
                emitEffect(.navigateToReader(book))
            }

        case let .openBookDetail(book):
            emitEffect(.navigateToDetail(book))

        case let .removeBook(bookUrl):
            deleteBook(bookUrl: bookUrl)

        default:
            break
        }
    }

    private func handleBatchIntent(_ intent: BookshelfIntent) {
        switch intent {
        case .toggleBatchMode:
            updateState {
                $0.isBatchMode.toggle()
                $0.selectedBookUrls.removeAll()
            }
            emitEffect(.hapticFeedback)

        case let .toggleSelectBook(bookUrl):
            updateState {
                if $0.selectedBookUrls.contains(bookUrl) {
                    $0.selectedBookUrls.remove(bookUrl)
                } else {
                    $0.selectedBookUrls.insert(bookUrl)
                }
            }
            emitEffect(.hapticFeedback)

        case .selectAll:
            updateState { $0.selectedBookUrls = Set($0.books.map(\.bookUrl)) }
            emitEffect(.hapticFeedback)

        case .deselectAll:
            updateState { $0.selectedBookUrls.removeAll() }
            emitEffect(.hapticFeedback)

        case .batchRemoveSelected:
            performBatchRemove()

        case let .batchMoveSelectedToGroup(groupName):
            performBatchMove(groupName: groupName)

        default:
            break
        }
    }

    private func handleGroupIntent(_ intent: BookshelfIntent) {
        switch intent {
        case let .addCustomGroup(name):
            performAddGroup(name: name)

        case let .deleteCustomGroup(id):
            performDeleteGroup(id: id)

        case let .moveBookToGroup(bookUrl, groupName):
            performMoveSingleBook(bookUrl: bookUrl, groupName: groupName)

        default:
            break
        }
    }

    private func loadData() {
        updateState { $0.isLoading = true }

        Task {
            do {
                let books = try await getBookshelfUseCase.execute()
                let customGroups = (try? await getBookGroupsUseCase?.execute()) ?? []
                let defaultGroups = ["全部", "在读", "未读", "完结"]
                let allGroupNames = defaultGroups + customGroups.map(\.name)

                self.updateState { state in
                    state.isLoading = false
                    state.books = books
                    state.customGroups = customGroups
                    state.groups = allGroupNames
                }
            } catch {
                self.updateState { $0.isLoading = false }
                self.emitEffect(.showToast("获取书架失败: \(error.localizedDescription)"))
            }
        }
    }

    private func refreshUpdates() {
        updateState {
            $0.isLoading = true
            $0.isRefreshingUpdates = true
        }

        Task {
            do {
                let updatedCount = try await checkBookUpdatesUseCase.execute()
                let books = try await getBookshelfUseCase.execute()
                let updatedUrls = Set(books.filter { $0.latestChapterTime > $0.durChapterTime }.map(\.bookUrl))

                self.updateState { state in
                    state.isLoading = false
                    state.isRefreshingUpdates = false
                    state.books = books
                    state.updatedBookUrls = updatedUrls
                }
                if updatedCount > 0 {
                    self.emitEffect(.showToast("全书架更新完成：\(updatedCount) 本书发现新章节"))
                } else {
                    self.emitEffect(.showToast("全部书籍均为最新"))
                }
                self.emitEffect(.hapticFeedback)
            } catch {
                self.updateState {
                    $0.isLoading = false
                    $0.isRefreshingUpdates = false
                }
            }
        }
    }

    private func deleteBook(bookUrl: String) {
        Task {
            do {
                try await removeBookFromShelfUseCase.execute(bookUrl: bookUrl)
                let books = try await getBookshelfUseCase.execute()
                self.updateState { $0.books = books }
                self.emitEffect(.showToast("已从书架移出"))
                self.emitEffect(.hapticFeedback)
            } catch {
                self.emitEffect(.showToast("移除失败: \(error.localizedDescription)"))
            }
        }
    }

    private func performBatchRemove() {
        let targets = Array(state.selectedBookUrls)
        guard !targets.isEmpty else { return }

        Task {
            for bookUrl in targets {
                try? await removeBookFromShelfUseCase.execute(bookUrl: bookUrl)
            }
            let books = (try? await getBookshelfUseCase.execute()) ?? []
            self.updateState {
                $0.books = books
                $0.selectedBookUrls.removeAll()
                $0.isBatchMode = false
            }
            self.emitEffect(.showToast("已成功移出 \(targets.count) 本书"))
            self.emitEffect(.hapticFeedback)
        }
    }

    private func performBatchMove(groupName: String?) {
        let targets = state.selectedBookUrls
        guard !targets.isEmpty, let saveBookToShelfUseCase else { return }

        Task {
            for book in state.books where targets.contains(book.bookUrl) {
                var updated = book
                updated.groupName = groupName
                try? await saveBookToShelfUseCase.execute(updated)
            }
            let books = (try? await getBookshelfUseCase.execute()) ?? []
            self.updateState {
                $0.books = books
                $0.selectedBookUrls.removeAll()
                $0.isBatchMode = false
            }
            let targetTitle = groupName ?? "未分组"
            self.emitEffect(.showToast("已将 \(targets.count) 本书移动至「\(targetTitle)」"))
            self.emitEffect(.hapticFeedback)
        }
    }

    private func performMoveSingleBook(bookUrl: String, groupName: String?) {
        guard let book = state.books.first(where: { $0.bookUrl == bookUrl }),
              let saveBookToShelfUseCase else { return }

        Task {
            var updated = book
            updated.groupName = groupName
            try? await saveBookToShelfUseCase.execute(updated)
            let books = (try? await getBookshelfUseCase.execute()) ?? []
            self.updateState { $0.books = books }
            let targetTitle = groupName ?? "未分组"
            self.emitEffect(.showToast("已将《\(book.name)》移动至「\(targetTitle)」"))
            self.emitEffect(.hapticFeedback)
        }
    }

    private func performAddGroup(name: String) {
        Task {
            let group = BookGroup(name: name, order: state.customGroups.count)
            try? await saveBookGroupUseCase?.execute(group)
            self.loadData()
            self.emitEffect(.showToast("分组「\(name)」创建成功"))
            self.emitEffect(.hapticFeedback)
        }
    }

    private func performDeleteGroup(id: String) {
        Task {
            try? await deleteBookGroupUseCase?.execute(id: id)
            self.loadData()
            self.emitEffect(.showToast("已删除分组"))
            self.emitEffect(.hapticFeedback)
        }
    }
}
