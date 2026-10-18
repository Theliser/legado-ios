import Foundation
import UIKit

/// 阅读器单一界面状态
public struct ReaderState: ViewState, Equatable, Sendable {
    public var book: Book
    public var chapters: [Chapter]
    public var currentChapterIndex: Int
    public var currentPageIndex: Int
    public var pages: [ReaderPage]
    public var config: ReaderConfig
    public var isHUDVisible: Bool
    public var isTocSheetVisible: Bool
    public var isConfigSheetVisible: Bool
    public var isLoading: Bool
    public var screenBounds: CGRect
    public var toastMessage: String?
    public var bookmarks: [Bookmark]

    public init(
        book: Book,
        chapters: [Chapter] = [],
        currentChapterIndex: Int = 0,
        currentPageIndex: Int = 0,
        pages: [ReaderPage] = [],
        config: ReaderConfig = ReaderConfig(),
        isHUDVisible: Bool = false,
        isTocSheetVisible: Bool = false,
        isConfigSheetVisible: Bool = false,
        isLoading: Bool = false,
        screenBounds: CGRect = .zero,
        toastMessage: String? = nil,
        bookmarks: [Bookmark] = []) {
        self.book = book
        self.chapters = chapters
        self.currentChapterIndex = currentChapterIndex
        self.currentPageIndex = currentPageIndex
        self.pages = pages
        self.config = config
        self.isHUDVisible = isHUDVisible
        self.isTocSheetVisible = isTocSheetVisible
        self.isConfigSheetVisible = isConfigSheetVisible
        self.isLoading = isLoading
        self.screenBounds = screenBounds
        self.toastMessage = toastMessage
        self.bookmarks = bookmarks
    }

    public var currentChapter: Chapter? {
        guard currentChapterIndex >= 0, currentChapterIndex < chapters.count else { return nil }
        return chapters[currentChapterIndex]
    }

    public var currentPage: ReaderPage? {
        guard currentPageIndex >= 0, currentPageIndex < pages.count else { return nil }
        return pages[currentPageIndex]
    }

    public var currentChapterText: String {
        pages.map(\.contentText).joined()
    }

    /// 当前章节当前页是否已被加为书签
    public var isCurrentPageBookmarked: Bool {
        guard let page = currentPage else { return false }
        return bookmarks.contains { bookmark in
            bookmark.chapterIndex == currentChapterIndex &&
                bookmark.chapterPos >= page.textRange.location &&
                bookmark.chapterPos < (page.textRange.location + max(page.textRange.length, 1))
        }
    }
}
