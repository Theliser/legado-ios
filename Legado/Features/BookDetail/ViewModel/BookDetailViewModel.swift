import Foundation

/// 书籍详情视图模型 (MVI 架构状态中枢)
@MainActor
public final class BookDetailViewModel: BaseMVIViewModel<BookDetailState, BookDetailIntent, BookDetailEffect> {
    private let getBookDetailUseCase: GetBookDetailUseCase
    private let getBookTocUseCase: GetBookTocUseCase
    private let saveBookToShelfUseCase: SaveBookToShelfUseCase
    private let removeBookFromShelfUseCase: RemoveBookFromShelfUseCase
    private let bookRepository: BookRepository
    private let batchDownloadChaptersUseCase: BatchDownloadChaptersUseCase?
    private let manageBookCacheUseCase: ManageBookCacheUseCase?
    private var downloadTask: Task<Void, Never>?

    public init(
        book: Book,
        getBookDetailUseCase: GetBookDetailUseCase,
        getBookTocUseCase: GetBookTocUseCase,
        saveBookToShelfUseCase: SaveBookToShelfUseCase,
        removeBookFromShelfUseCase: RemoveBookFromShelfUseCase,
        bookRepository: BookRepository,
        batchDownloadChaptersUseCase: BatchDownloadChaptersUseCase? = nil,
        manageBookCacheUseCase: ManageBookCacheUseCase? = nil) {
        self.getBookDetailUseCase = getBookDetailUseCase
        self.getBookTocUseCase = getBookTocUseCase
        self.saveBookToShelfUseCase = saveBookToShelfUseCase
        self.removeBookFromShelfUseCase = removeBookFromShelfUseCase
        self.bookRepository = bookRepository
        self.batchDownloadChaptersUseCase = batchDownloadChaptersUseCase
        self.manageBookCacheUseCase = manageBookCacheUseCase

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

        case .openToc, .closeToc, .toggleTocReverse, .updateTocSearch, .selectChapter:
            handleTocIntent(intent)

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

        case .toggleCacheSheet, .refreshCacheInfo, .startBatchDownload,
             .cancelBatchDownload, .clearBookCache:
            handleCacheIntent(intent)
        }
    }

    private func handleTocIntent(_ intent: BookDetailIntent) {
        switch intent {
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

        default:
            break
        }
    }

    private func handleCacheIntent(_ intent: BookDetailIntent) {
        switch intent {
        case let .toggleCacheSheet(isOpen):
            updateState { $0.isCacheSheetPresented = isOpen }
            if isOpen {
                send(.refreshCacheInfo)
            }
            emitEffect(.hapticFeedback)

        case .refreshCacheInfo:
            refreshCacheStatus()

        case let .startBatchDownload(option):
            startDownload(option: option)

        case .cancelBatchDownload:
            cancelDownload()

        case .clearBookCache:
            clearCache()

        default:
            break
        }
    }

    private func refreshCacheStatus() {
        guard let manageBookCacheUseCase else { return }
        let info = manageBookCacheUseCase.getBookCacheInfo(
            bookUrl: state.book.bookUrl,
            totalChapters: state.chapters.count)
        updateState { $0.cacheInfo = info }
    }

    private func startDownload(option: BatchDownloadOption) {
        guard let batchDownloadChaptersUseCase else { return }
        downloadTask?.cancel()

        updateState {
            $0.downloadProgress = BatchDownloadProgress(
                bookUrl: state.book.bookUrl,
                bookName: state.book.name,
                totalChaptersToDownload: 0,
                completedChaptersCount: 0,
                status: .downloading)
        }

        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await batchDownloadChaptersUseCase.execute(
                    book: state.book,
                    chapters: state.chapters,
                    option: option,
                    concurrency: 3) { progress in
                        Task { @MainActor in
                            self.updateState { $0.downloadProgress = progress }
                        }
                    }
                self.refreshCacheStatus()
                self.emitEffect(.showToast("离线缓存完成！"))
                self.emitEffect(.hapticFeedback)
            } catch is CancellationError {
                self.updateState { $0.downloadProgress?.status = .paused }
                self.emitEffect(.showToast("已暂停/取消下载"))
            } catch {
                self.updateState { $0.downloadProgress?.status = .failed(error.localizedDescription) }
                self.emitEffect(.showToast("下载出现异常: \(error.localizedDescription)"))
            }
        }
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        updateState { $0.downloadProgress?.status = .idle }
        emitEffect(.showToast("已取消下载任务"))
        emitEffect(.hapticFeedback)
    }

    private func clearCache() {
        guard let manageBookCacheUseCase else { return }
        do {
            try manageBookCacheUseCase.clearBookCache(bookUrl: state.book.bookUrl)
            refreshCacheStatus()
            emitEffect(.showToast("已清空《\(state.book.name)》离线缓存"))
            emitEffect(.hapticFeedback)
        } catch {
            emitEffect(.showToast("清理缓存失败: \(error.localizedDescription)"))
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
