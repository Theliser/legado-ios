import Foundation

/// 书架分组领域模型
public struct BookGroup: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var order: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        order: Int = 0) {
        self.id = id
        self.name = name
        self.order = order
    }
}
