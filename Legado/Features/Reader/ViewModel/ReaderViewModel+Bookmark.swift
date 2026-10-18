import Foundation

// MARK: - 书签与划线笔记扩展 (Bookmark & Highlights)

extension ReaderViewModel {
    func loadBookmarks() {
        guard let getBookmarksUseCase else { return }
        Task {
            if let list = try? await getBookmarksUseCase.execute(
                bookName: state.book.name,
                bookAuthor: state.book.author) {
                self.updateState { $0.bookmarks = list }
            }
        }
    }

    func handleBookmarkIntent(_ intent: ReaderIntent) {
        switch intent {
        case .loadBookmarks:
            loadBookmarks()

        case .toggleBookmark:
            handleToggleBookmark()

        case let .addBookmark(chapterIndex, chapterPos, chapterTitle, bookText, note):
            handleAddBookmark(
                chapterIndex: chapterIndex,
                chapterPos: chapterPos,
                chapterTitle: chapterTitle,
                bookText: bookText,
                note: note)

        case let .deleteBookmark(id):
            handleDeleteBookmark(id: id)

        default:
            break
        }
    }

    private func handleToggleBookmark() {
        guard let page = state.currentPage else { return }
        let existingBookmark = state.bookmarks.first { bookmark in
            bookmark.chapterIndex == state.currentChapterIndex &&
                bookmark.chapterPos >= page.textRange.location &&
                bookmark.chapterPos < (page.textRange.location + max(page.textRange.length, 1))
        }

        if let existing = existingBookmark {
            handleDeleteBookmark(id: existing.id)
        } else {
            let excerpt = String(page.contentText.prefix(120))
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let bookmark = Bookmark(
                bookName: state.book.name,
                bookAuthor: state.book.author,
                bookUrl: state.book.bookUrl,
                chapterIndex: state.currentChapterIndex,
                chapterPos: page.textRange.location,
                chapterName: state.currentChapter?.title ?? "第\(state.currentChapterIndex + 1)章",
                bookText: excerpt)
            Task {
                try? await saveBookmarkUseCase?.execute(bookmark: bookmark)
                self.loadBookmarks()
                self.emitEffect(.showToast("已添加书签"))
                self.emitEffect(.hapticFeedback)
            }
        }
    }

    private func handleAddBookmark(
        chapterIndex: Int,
        chapterPos: Int,
        chapterTitle: String,
        bookText: String,
        note: String) {
        let bookmark = Bookmark(
            bookName: state.book.name,
            bookAuthor: state.book.author,
            bookUrl: state.book.bookUrl,
            chapterIndex: chapterIndex,
            chapterPos: chapterPos,
            chapterName: chapterTitle,
            bookText: bookText,
            content: note)
        Task {
            try? await saveBookmarkUseCase?.execute(bookmark: bookmark)
            self.loadBookmarks()
            self.emitEffect(.showToast("书签已保存"))
            self.emitEffect(.hapticFeedback)
        }
    }

    private func handleDeleteBookmark(id: String) {
        Task {
            try? await deleteBookmarkUseCase?.execute(id: id)
            self.loadBookmarks()
            self.emitEffect(.showToast("已移除书签"))
            self.emitEffect(.hapticFeedback)
        }
    }
}
