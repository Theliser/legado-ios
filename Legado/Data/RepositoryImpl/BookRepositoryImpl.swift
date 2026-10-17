import Foundation
import SwiftData

/// 基于 SwiftData @ModelActor 的书籍与书架仓储实现
@ModelActor
public actor BookRepositoryImpl: BookRepository {
    public func getBookshelf() throws -> [Book] {
        let descriptor = FetchDescriptor<BookEntity>(
            sortBy: [
                SortDescriptor(\.durChapterTime, order: .reverse),
                SortDescriptor(\.customOrder, order: .forward),
            ])
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }

    public func getBook(by url: String) throws -> Book? {
        let predicate = #Predicate<BookEntity> { $0.bookUrl == url }
        let descriptor = FetchDescriptor<BookEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func saveBook(_ book: Book) throws {
        let targetUrl = book.bookUrl
        let predicate = #Predicate<BookEntity> { $0.bookUrl == targetUrl }
        let descriptor = FetchDescriptor<BookEntity>(predicate: predicate)

        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = book.name
            existing.author = book.author
            existing.tocUrl = book.tocUrl
            existing.origin = book.origin
            existing.originName = book.originName
            existing.kind = book.kind
            existing.coverUrl = book.coverUrl
            existing.intro = book.intro
            existing.latestChapterTitle = book.latestChapterTitle
            existing.latestChapterTime = book.latestChapterTime
            existing.durChapterTitle = book.durChapterTitle
            existing.durChapterIndex = book.durChapterIndex
            existing.durChapterPos = book.durChapterPos
            existing.durChapterTime = book.durChapterTime
            existing.wordCount = book.wordCount
            existing.customOrder = book.order
            existing.totalChapterNum = book.totalChapterNum
        } else {
            let entity = BookEntity(from: book)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }

    public func removeBook(by url: String) throws {
        let predicate = #Predicate<BookEntity> { $0.bookUrl == url }
        let descriptor = FetchDescriptor<BookEntity>(predicate: predicate)
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }

        // 连带清理该书籍的章节缓存
        let chapterPredicate = #Predicate<ChapterEntity> { $0.bookUrl == url }
        let chapterDescriptor = FetchDescriptor<ChapterEntity>(predicate: chapterPredicate)
        let chapters = try modelContext.fetch(chapterDescriptor)
        for chapter in chapters {
            modelContext.delete(chapter)
        }

        try modelContext.save()
    }

    public func getChapters(for bookUrl: String) throws -> [Chapter] {
        let predicate = #Predicate<ChapterEntity> { $0.bookUrl == bookUrl }
        let descriptor = FetchDescriptor<ChapterEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.index, order: .forward)])
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }

    public func saveChapters(_ chapters: [Chapter], for bookUrl: String) throws {
        // 先删除旧章节以防索引错位
        let predicate = #Predicate<ChapterEntity> { $0.bookUrl == bookUrl }
        let descriptor = FetchDescriptor<ChapterEntity>(predicate: predicate)
        let existing = try modelContext.fetch(descriptor)
        for item in existing {
            modelContext.delete(item)
        }

        for chapter in chapters {
            let entity = ChapterEntity(from: chapter)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }

    public func getReadRecord(bookName: String, bookAuthor: String) throws -> ReadRecord? {
        let targetId = "\(bookName)_\(bookAuthor)"
        let predicate = #Predicate<ReadRecordEntity> { $0.id == targetId }
        let descriptor = FetchDescriptor<ReadRecordEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func saveReadRecord(_ record: ReadRecord) throws {
        let targetId = record.id
        let predicate = #Predicate<ReadRecordEntity> { $0.id == targetId }
        let descriptor = FetchDescriptor<ReadRecordEntity>(predicate: predicate)

        if let existing = try modelContext.fetch(descriptor).first {
            existing.readTimeSeconds = record.readTimeSeconds
            existing.lastReadDate = record.lastReadDate
            existing.wordsRead = record.wordsRead
        } else {
            let entity = ReadRecordEntity(from: record)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }
}
