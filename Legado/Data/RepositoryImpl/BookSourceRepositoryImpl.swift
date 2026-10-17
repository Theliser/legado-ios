import Foundation
import SwiftData

/// 基于 SwiftData @ModelActor 的书源仓储实现，保证线程安全与后台并发读写
@ModelActor
public actor BookSourceRepositoryImpl: BookSourceRepository {
    public func fetchSources() throws -> [BookSource] {
        let descriptor = FetchDescriptor<BookSourceEntity>(
            sortBy: [SortDescriptor(\.customOrder, order: .forward)])
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    public func fetchEnabledSources() throws -> [BookSource] {
        let predicate = #Predicate<BookSourceEntity> { $0.enabled == true }
        let descriptor = FetchDescriptor<BookSourceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.customOrder, order: .forward)])
        let entities = try modelContext.fetch(descriptor)
        return entities.compactMap { $0.toDomain() }
    }

    public func saveSources(_ sources: [BookSource]) throws {
        for source in sources {
            let targetUrl = source.bookSourceUrl
            let predicate = #Predicate<BookSourceEntity> { $0.bookSourceUrl == targetUrl }
            let descriptor = FetchDescriptor<BookSourceEntity>(predicate: predicate)

            if let existing = try modelContext.fetch(descriptor).first {
                existing.bookSourceName = source.bookSourceName
                existing.bookSourceGroup = source.bookSourceGroup
                existing.bookSourceType = source.bookSourceType ?? 0
                existing.enabled = source.enabled ?? true
                existing.customOrder = source.customOrder ?? 0
                if let data = try? JSONEncoder().encode(source),
                   let json = String(data: data, encoding: .utf8) {
                    existing.rawJson = json
                }
            } else {
                let entity = BookSourceEntity(from: source)
                modelContext.insert(entity)
            }
        }
        try modelContext.save()
    }

    public func updateSource(_ source: BookSource) throws {
        try saveSources([source])
    }

    public func deleteSource(url: String) throws {
        let predicate = #Predicate<BookSourceEntity> { $0.bookSourceUrl == url }
        let descriptor = FetchDescriptor<BookSourceEntity>(predicate: predicate)
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }

    public func clearSources() throws {
        try modelContext.delete(model: BookSourceEntity.self)
        try modelContext.save()
    }
}
