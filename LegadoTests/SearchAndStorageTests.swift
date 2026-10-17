import Foundation
@testable import Legado
import SwiftData
import Testing

@Suite("Search and SwiftData Storage Suite")
struct SearchAndStorageTests {
    @Test("Test SwiftData BookSource Entity CRUD")
    func bookSourceStorage() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let repo = BookSourceRepositoryImpl(modelContainer: provider.container)

        let sampleSource = BookSource(
            bookSourceUrl: "https://www.example.com",
            bookSourceName: "测试笔趣阁",
            bookSourceGroup: "优质",
            bookSourceType: 0,
            searchUrl: "https://www.example.com/search?q={{key}}",
            enabled: true,
            customOrder: 1)

        try await repo.saveSources([sampleSource])

        let fetched = try await repo.fetchSources()
        #expect(fetched.count == 1)
        #expect(fetched.first?.bookSourceName == "测试笔趣阁")
        #expect(fetched.first?.bookSourceUrl == "https://www.example.com")

        // Update
        var updated = sampleSource
        updated.bookSourceName = "修改后笔趣阁"
        try await repo.updateSource(updated)

        let afterUpdate = try await repo.fetchSources()
        #expect(afterUpdate.first?.bookSourceName == "修改后笔趣阁")

        // Delete
        try await repo.deleteSource(url: "https://www.example.com")
        let afterDelete = try await repo.fetchSources()
        #expect(afterDelete.isEmpty)
    }

    @Test("Test SwiftData Book and Chapter Persistence")
    func bookAndChapterStorage() async throws {
        let provider = ModelContainerProvider(inMemory: true)
        let repo = BookRepositoryImpl(modelContainer: provider.container)

        let book = Book(
            bookUrl: "https://www.example.com/book/123",
            tocUrl: "https://www.example.com/book/123/toc",
            origin: "https://www.example.com",
            originName: "测试书源",
            name: "诡秘之主",
            author: "爱潜水的乌贼",
            kind: "西方玄幻",
            intro: "蒸汽与机械的浪潮中...")

        try await repo.saveBook(book)

        let shelf = try await repo.getBookshelf()
        #expect(shelf.count == 1)
        #expect(shelf.first?.name == "诡秘之主")
        #expect(shelf.first?.author == "爱潜水的乌贼")

        // Save chapters
        let chapters = [
            Chapter(url: "https://www.example.com/c1", title: "第一章 绯红", bookUrl: book.bookUrl, index: 0),
            Chapter(url: "https://www.example.com/c2", title: "第二章 宿命", bookUrl: book.bookUrl, index: 1),
        ]
        try await repo.saveChapters(chapters, for: book.bookUrl)

        let fetchedChapters = try await repo.getChapters(for: book.bookUrl)
        #expect(fetchedChapters.count == 2)
        #expect(fetchedChapters[0].title == "第一章 绯红")

        // Read Record
        let record = ReadRecord(bookName: "诡秘之主", bookAuthor: "爱潜水的乌贼", readTimeSeconds: 3600, wordsRead: 15000)
        try await repo.saveReadRecord(record)

        let fetchedRecord = try await repo.getReadRecord(bookName: "诡秘之主", bookAuthor: "爱潜水的乌贼")
        #expect(fetchedRecord != nil)
        #expect(fetchedRecord?.wordsRead == 15000)

        // Remove book
        try await repo.removeBook(by: book.bookUrl)
        let emptyShelf = try await repo.getBookshelf()
        #expect(emptyShelf.isEmpty)
        let emptyChapters = try await repo.getChapters(for: book.bookUrl)
        #expect(emptyChapters.isEmpty)
    }

    @Test("Test Multi-Source Search Results Aggregation and De-duplication")
    func searchAggregation() {
        let provider = ModelContainerProvider(inMemory: true)
        let repo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let useCase = SearchBooksUseCase(sourceRepository: repo)

        let results = [
            SearchResult(
                bookUrl: "https://source1.com/book/1",
                origin: "https://source1.com",
                originName: "源一",
                originOrder: 1,
                name: "诡秘之主",
                author: "爱潜水的乌贼",
                intro: "短简介",
                latestChapterTitle: "第100章"),
            SearchResult(
                bookUrl: "https://source2.com/book/1",
                origin: "https://source2.com",
                originName: "源二",
                originOrder: 2,
                name: "诡秘之主",
                author: "爱潜水的乌贼",
                coverUrl: "https://source2.com/cover.jpg",
                intro: "超长详细简介...",
                latestChapterTitle: "第150章"),
            SearchResult(
                bookUrl: "https://source1.com/book/99",
                origin: "https://source1.com",
                originName: "源一",
                originOrder: 1,
                name: "宿命之环",
                author: "爱潜水的乌贼"),
        ]

        let groups = useCase.aggregateAndSort(results: results, keyword: "诡秘之主")
        #expect(groups.count == 2)

        let firstGroup = groups.first
        #expect(firstGroup?.name == "诡秘之主")
        #expect(firstGroup?.sources.count == 2)
        #expect(firstGroup?.coverUrl == "https://source2.com/cover.jpg")
    }

    @Test("Test SearchBooksUseCase with Empty Sources")
    func searchWithEmptySources() async {
        let provider = ModelContainerProvider(inMemory: true)
        let repo = BookSourceRepositoryImpl(modelContainer: provider.container)
        let useCase = SearchBooksUseCase(sourceRepository: repo)

        var events: [SearchProgressEvent] = []
        for await event in useCase.execute(keyword: "测试") {
            events.append(event)
        }

        #expect(!events.isEmpty)
        if case let .allCompleted(groups) = events.last {
            #expect(groups.isEmpty)
        } else {
            Issue.record("Expected allCompleted event")
        }
    }
}
