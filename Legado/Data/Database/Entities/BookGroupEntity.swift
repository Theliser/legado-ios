import Foundation
import SwiftData

/// SwiftData 书架分组实体
@Model
public final class BookGroupEntity {
    @Attribute(.unique) public var id: String
    public var name: String
    public var order: Int

    public init(id: String, name: String, order: Int = 0) {
        self.id = id
        self.name = name
        self.order = order
    }

    public convenience init(from domain: BookGroup) {
        self.init(id: domain.id, name: domain.name, order: domain.order)
    }

    public func toDomain() -> BookGroup {
        BookGroup(id: id, name: name, order: order)
    }
}
