import Foundation
import UIKit

/// 阅读器核心控制器 (MVI 架构)
@MainActor
public final class ReaderViewModel: BaseMVIViewModel<ReaderState, ReaderIntent, ReaderEffect> {
    private let getChapterContentUseCase: GetChapterContentUseCase
    private let getBookTocUseCase: GetBookTocUseCase
    private let bookRepository: BookRepository
    private let textLayoutEngine: TextLayoutEngine

    public init(
        book: Book,
        initialChapterIndex: Int? = nil,
        showHUDInitially: Bool = false,
        getChapterContentUseCase: GetChapterContentUseCase,
        getBookTocUseCase: GetBookTocUseCase,
        bookRepository: BookRepository,
        textLayoutEngine: TextLayoutEngine = .shared) {
        self.getChapterContentUseCase = getChapterContentUseCase
        self.getBookTocUseCase = getBookTocUseCase
        self.bookRepository = bookRepository
        self.textLayoutEngine = textLayoutEngine

        let startChapter = initialChapterIndex ?? book.durChapterIndex
        super.init(initialState: ReaderState(
            book: book,
            currentChapterIndex: startChapter,
            isHUDVisible: showHUDInitially))

        loadTocAndStartReading()
    }

    private func loadTocAndStartReading() {
        Task {
            let local = (try? await bookRepository.getChapters(for: state.book.bookUrl)) ?? []
            if !local.isEmpty {
                self.updateState { state in
                    state.chapters = local
                }
                self.send(.loadChapter(state.currentChapterIndex))
                return
            }

            var toc = (try? await getBookTocUseCase.execute(book: state.book)) ?? []
            if toc.isEmpty {
                toc = [
                    Chapter(
                        url: state.book.bookUrl,
                        title: state.book.durChapterTitle ?? "第一章 宿命之始",
                        bookUrl: state.book.bookUrl,
                        index: 0),
                ]
            }
            self.updateState { state in
                state.chapters = toc
            }
            self.send(.loadChapter(state.currentChapterIndex))
        }
    }

    override public func send(_ intent: ReaderIntent) {
        switch intent {
        case .loadChapter, .nextPage, .prevPage, .jumpToPage:
            handleNavigationIntent(intent)

        case .toggleHUD, .hideHUD, .openToc, .closeToc:
            handleHUDIntent(intent)

        case .openConfig, .closeConfig, .changeFontSize, .selectTheme:
            handleConfigIntent(intent)

        case let .updateScreenBounds(rect):
            if state.screenBounds != rect, rect.width > 50 {
                updateState { $0.screenBounds = rect }
                repaginateCurrentChapter()
            }
        }
    }

    private func handleNavigationIntent(_ intent: ReaderIntent) {
        switch intent {
        case let .loadChapter(index):
            loadChapterContent(chapterIndex: index, targetPageIndex: 0)

        case .nextPage:
            handleNextPage()

        case .prevPage:
            handlePrevPage()

        case let .jumpToPage(index):
            if index >= 0, index < state.pages.count {
                updateState { $0.currentPageIndex = index }
                saveReadingProgress()
                emitEffect(.hapticFeedback)
            }

        default:
            break
        }
    }

    private func handleHUDIntent(_ intent: ReaderIntent) {
        switch intent {
        case .toggleHUD:
            updateState { $0.isHUDVisible.toggle() }
            emitEffect(.hapticFeedback)

        case .hideHUD:
            updateState {
                $0.isHUDVisible = false
                $0.isConfigSheetVisible = false
            }

        case .openToc:
            updateState {
                $0.isHUDVisible = false
                $0.isTocSheetVisible = true
            }
            emitEffect(.hapticFeedback)

        case .closeToc:
            updateState { $0.isTocSheetVisible = false }

        default:
            break
        }
    }

    private func handleConfigIntent(_ intent: ReaderIntent) {
        switch intent {
        case .openConfig:
            updateState { $0.isConfigSheetVisible = true }
            emitEffect(.hapticFeedback)

        case .closeConfig:
            updateState { $0.isConfigSheetVisible = false }

        case let .changeFontSize(delta):
            let newSize = min(max(state.config.fontSize + delta, 12), 34)
            var newConfig = state.config
            newConfig.fontSize = newSize
            applyNewConfig(newConfig)

        case let .selectTheme(theme):
            var newConfig = state.config
            newConfig.theme = theme
            applyNewConfig(newConfig)

        default:
            break
        }
    }

    private func loadChapterContent(chapterIndex: Int, targetPageIndex: Int) {
        guard chapterIndex >= 0, chapterIndex < state.chapters.count else { return }

        let chapter = state.chapters[chapterIndex]
        updateState {
            $0.isLoading = true
            $0.currentChapterIndex = chapterIndex
        }

        Task {
            do {
                let content = try await getChapterContentUseCase.execute(
                    chapter: chapter,
                    origin: state.book.origin)

                let defaultBounds = CGRect(x: 0, y: 0, width: 393, height: 852)
                let layoutBounds = state.screenBounds.width > 50 ? state.screenBounds : defaultBounds
                let pages = textLayoutEngine.paginate(
                    chapterTitle: chapter.title,
                    content: content,
                    chapterIndex: chapterIndex,
                    bounds: layoutBounds,
                    config: state.config)

                let safePageIndex = min(max(targetPageIndex, 0), max(pages.count - 1, 0))

                self.updateState { state in
                    state.isLoading = false
                    state.pages = pages
                    state.currentPageIndex = safePageIndex
                }

                self.saveReadingProgress()

                // 预加载下一章节
                if chapterIndex + 1 < state.chapters.count {
                    let nextChapter = state.chapters[chapterIndex + 1]
                    self.getChapterContentUseCase.preload(chapter: nextChapter, origin: state.book.origin)
                }
            } catch {
                self.updateState { state in
                    state.isLoading = false
                    state.toastMessage = "加载章节失败: \(error.localizedDescription)"
                }
                self.emitEffect(.showToast("章节加载失败: \(error.localizedDescription)"))
            }
        }
    }

    private func handleNextPage() {
        if state.currentPageIndex + 1 < state.pages.count {
            updateState { $0.currentPageIndex += 1 }
            saveReadingProgress()
            emitEffect(.hapticFeedback)
        } else if state.currentChapterIndex + 1 < state.chapters.count {
            // 翻入下一章第一页
            loadChapterContent(chapterIndex: state.currentChapterIndex + 1, targetPageIndex: 0)
            emitEffect(.hapticFeedback)
        } else {
            emitEffect(.showToast("已经是最后一页了"))
        }
    }

    private func handlePrevPage() {
        if state.currentPageIndex > 0 {
            updateState { $0.currentPageIndex -= 1 }
            saveReadingProgress()
            emitEffect(.hapticFeedback)
        } else if state.currentChapterIndex > 0 {
            // 翻入上一章最后一页
            loadChapterContent(chapterIndex: state.currentChapterIndex - 1, targetPageIndex: Int.max)
            emitEffect(.hapticFeedback)
        } else {
            emitEffect(.showToast("已经是第一页了"))
        }
    }

    private func repaginateCurrentChapter() {
        guard let chapter = state.currentChapter else { return }
        Task {
            if let content = try? await getChapterContentUseCase.execute(chapter: chapter, origin: state.book.origin) {
                let pages = textLayoutEngine.paginate(
                    chapterTitle: chapter.title,
                    content: content,
                    chapterIndex: state.currentChapterIndex,
                    bounds: state.screenBounds,
                    config: state.config)
                self.updateState { state in
                    state.pages = pages
                    state.currentPageIndex = min(state.currentPageIndex, max(pages.count - 1, 0))
                }
            }
        }
    }

    private func applyNewConfig(_ newConfig: ReaderConfig) {
        updateState { $0.config = newConfig }
        repaginateCurrentChapter()
        emitEffect(.hapticFeedback)
    }

    private func saveReadingProgress() {
        guard let chapter = state.currentChapter else { return }
        var updated = state.book
        updated.durChapterIndex = state.currentChapterIndex
        updated.durChapterTitle = chapter.title
        updated.durChapterTime = Int64(Date().timeIntervalSince1970 * 1000)

        Task {
            try? await bookRepository.saveBook(updated)
        }
    }
}
