import Foundation
@testable import Legado
import Testing

@Suite("Bookmark and Note Suite")
struct BookmarkTests {
    @Test("Test Bookmark Model Properties and Formatted Date")
    func bookmarkModel() {
        let timestamp: Int64 = 1_729_238_400_000 // 2024-10-18 ~
        let bookmark = Bookmark(
            time: timestamp,
            bookName: "宿命之环",
            bookAuthor: "爱潜水的乌贼",
            bookUrl: "https://example.com/book",
            chapterIndex: 3,
            chapterPos: 120,
            chapterName: "第四章 密室之谜",
            bookText: "他在抽屉深处摸到了一把古旧铜钥匙。",
            content: "非常关键的伏笔！")

        #expect(bookmark.bookName == "宿命之环")
        #expect(bookmark.chapterIndex == 3)
        #expect(bookmark.chapterPos == 120)
        #expect(bookmark.content == "非常关键的伏笔！")
        #expect(!bookmark.id.isEmpty)
        #expect(!bookmark.formattedDate.isEmpty)
    }

    @Test("Test BookmarkRepositoryImpl SwiftData CRUD")
    func repositoryCRUD() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let repository = BookmarkRepositoryImpl(modelContainer: provider.container)

        let b1 = Bookmark(
            time: 1000,
            bookName: "测试书名",
            bookAuthor: "测试作者",
            bookUrl: "https://test.com/b",
            chapterIndex: 0,
            chapterPos: 50,
            chapterName: "第一章",
            bookText: "摘录片段 1")

        let b2 = Bookmark(
            time: 2000,
            bookName: "测试书名",
            bookAuthor: "测试作者",
            bookUrl: "https://test.com/b",
            chapterIndex: 1,
            chapterPos: 20,
            chapterName: "第二章",
            bookText: "摘录片段 2",
            content: "我的笔记")

        // 1. 保存书签
        try await repository.saveBookmark(b1)
        try await repository.saveBookmark(b2)

        // 2. 查询书签
        let bookmarks = try await repository.getBookmarks(bookName: "测试书名", bookAuthor: "测试作者")
        #expect(bookmarks.count == 2)
        #expect(bookmarks[0].chapterIndex == 0)
        #expect(bookmarks[1].chapterIndex == 1)
        #expect(bookmarks[1].content == "我的笔记")

        // 3. 删除单个书签
        try await repository.deleteBookmark(id: b1.id)
        let afterDelete1 = try await repository.getBookmarks(bookName: "测试书名", bookAuthor: "测试作者")
        #expect(afterDelete1.count == 1)
        #expect(afterDelete1.first?.id == b2.id)

        // 4. 批量删除
        try await repository.deleteBookmarks(ids: [b2.id])
        let afterDeleteAll = try await repository.getBookmarks(bookName: "测试书名", bookAuthor: "测试作者")
        #expect(afterDeleteAll.isEmpty)
    }

    @Test("Test ReaderViewModel Bookmark MVI Intent Lifecycle")
    @MainActor
    func readerViewModelBookmarkFlow() async {
        let provider = ModelContainerProvider(inMemory: true)
        let bookRepo = BookRepositoryImpl(modelContainer: provider.container)
        let sourceRepo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let bookmarkRepo = BookmarkRepositoryImpl(modelContainer: provider.container)

        let getChapterContentUseCase = GetChapterContentUseCase(sourceRepository: sourceRepo)
        let getBookTocUseCase = GetBookTocUseCase(sourceRepository: sourceRepo, bookRepository: bookRepo)
        let getBookmarksUseCase = GetBookmarksUseCase(bookmarkRepository: bookmarkRepo)
        let saveBookmarkUseCase = SaveBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        let deleteBookmarkUseCase = DeleteBookmarkUseCase(bookmarkRepository: bookmarkRepo)

        let book = Book(
            bookUrl: "https://test.com/book_bm",
            tocUrl: "https://test.com/book_bm/toc",
            origin: "https://test.com",
            originName: "测试书源",
            name: "书签测试书",
            author: "作者X")

        let chapters = [
            Chapter(url: "https://test.com/c1", title: "第一章 序幕", bookUrl: book.bookUrl, index: 0),
        ]

        try? await bookRepo.saveBook(book)
        try? await bookRepo.saveChapters(chapters, for: book.bookUrl)

        getChapterContentUseCase.saveChapterCache(
            content: "阳光透过窗帘的缝隙洒进书房，照亮了书桌上摊开的手稿。",
            bookUrl: book.bookUrl,
            index: 0)

        let viewModel = ReaderViewModel(
            book: book,
            initialChapterIndex: 0,
            getChapterContentUseCase: getChapterContentUseCase,
            getBookTocUseCase: getBookTocUseCase,
            bookRepository: bookRepo,
            getBookmarksUseCase: getBookmarksUseCase,
            saveBookmarkUseCase: saveBookmarkUseCase,
            deleteBookmarkUseCase: deleteBookmarkUseCase)

        // 等待初始加载章节与排版
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(viewModel.state.bookmarks.isEmpty)
        #expect(!viewModel.state.isCurrentPageBookmarked)

        // 1. 触发切换书签 (添加)
        viewModel.send(.toggleBookmark)
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(viewModel.state.bookmarks.count == 1)
        #expect(viewModel.state.isCurrentPageBookmarked)
        #expect(viewModel.state.bookmarks.first?.chapterTitleOrName == "第一章 序幕")

        // 2. 再次触发切换书签 (删除)
        viewModel.send(.toggleBookmark)
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(viewModel.state.bookmarks.isEmpty)
        #expect(!viewModel.state.isCurrentPageBookmarked)

        // 3. 添加带笔记的书签
        viewModel.send(.addBookmark(
            chapterIndex: 0,
            chapterPos: 10,
            chapterTitle: "第一章 序幕",
            bookText: "摊开的手稿",
            note: "关键线索"))
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(viewModel.state.bookmarks.count == 1)
        #expect(viewModel.state.bookmarks.first?.content == "关键线索")
    }
}

private extension Bookmark {
    var chapterTitleOrName: String {
        chapterName
    }
}
