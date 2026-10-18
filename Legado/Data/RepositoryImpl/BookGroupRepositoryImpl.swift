import Foundation
import SwiftData

/// 基于 SwiftData @ModelActor 的书架分组仓储实现
@ModelActor
public actor BookGroupRepositoryImpl: BookGroupRepository {
    public func getGroups() throws -> [BookGroup] {
        let descriptor = FetchDescriptor<BookGroupEntity>(
            sortBy: [SortDescriptor(\.order, order: .forward)])
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toDomain() }
    }

    public func saveGroup(_ group: BookGroup) throws {
        let targetId = group.id
        let predicate = #Predicate<BookGroupEntity> { $0.id == targetId }
        let descriptor = FetchDescriptor<BookGroupEntity>(predicate: predicate)

        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = group.name
            existing.order = group.order
        } else {
            let entity = BookGroupEntity(from: group)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }

    public func deleteGroup(id: String) throws {
        let predicate = #Predicate<BookGroupEntity> { $0.id == id }
        let descriptor = FetchDescriptor<BookGroupEntity>(predicate: predicate)
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
    }
}
