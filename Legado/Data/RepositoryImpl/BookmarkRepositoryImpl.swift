import Foundation
import SwiftData

/// 基于 SwiftData @ModelActor 的书签数据仓储实现
@ModelActor
public actor BookmarkRepositoryImpl: BookmarkRepository {
    public func getBookmarks(bookName: String, bookAuthor: String) throws -> [Bookmark] {
        let predicate = #Predicate<BookmarkEntity> { entity in
            entity.bookName == bookName && entity.bookAuthor == bookAuthor
        }
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: predicate,
            sortBy: [
                SortDescriptor(\.chapterIndex, order: .forward),
                SortDescriptor(\.chapterPos, order: .forward),
                SortDescriptor(\.time, order: .reverse),
            ])
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }

    public func saveBookmark(_ bookmark: Bookmark) throws {
        let targetId = bookmark.id
        let predicate = #Predicate<BookmarkEntity> { entity in
            entity.id == targetId
        }
        let descriptor = FetchDescriptor<BookmarkEntity>(predicate: predicate)

        if let existing = try modelContext.fetch(descriptor).first {
            existing.chapterIndex = bookmark.chapterIndex
            existing.chapterPos = bookmark.chapterPos
            existing.chapterName = bookmark.chapterName
            existing.bookText = bookmark.bookText
            existing.content = bookmark.content
        } else {
            let entity = BookmarkEntity(from: bookmark)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }

    public func deleteBookmark(id: String) throws {
        let predicate = #Predicate<BookmarkEntity> { entity in
            entity.id == id
        }
        let descriptor = FetchDescriptor<BookmarkEntity>(predicate: predicate)
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    public func deleteBookmarks(ids: [String]) throws {
        for id in ids {
            let predicate = #Predicate<BookmarkEntity> { entity in
                entity.id == id
            }
            let descriptor = FetchDescriptor<BookmarkEntity>(predicate: predicate)
            let entities = try modelContext.fetch(descriptor)
            for entity in entities {
                modelContext.delete(entity)
            }
        }
        try modelContext.save()
    }
}
