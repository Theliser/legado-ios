import Foundation
import SwiftData

/// SwiftData 书源持久化实体
@Model
public final class BookSourceEntity {
    @Attribute(.unique) public var bookSourceUrl: String
    public var bookSourceName: String
    public var bookSourceGroup: String?
    public var bookSourceType: Int
    public var enabled: Bool
    public var customOrder: Int
    /// 完整 JSON 保证所有扩展规则字段无损序列化
    public var rawJson: String

    public init(
        bookSourceUrl: String,
        bookSourceName: String,
        bookSourceGroup: String? = nil,
        bookSourceType: Int = 0,
        enabled: Bool = true,
        customOrder: Int = 0,
        rawJson: String) {
        self.bookSourceUrl = bookSourceUrl
        self.bookSourceName = bookSourceName
        self.bookSourceGroup = bookSourceGroup
        self.bookSourceType = bookSourceType
        self.enabled = enabled
        self.customOrder = customOrder
        self.rawJson = rawJson
    }

    public convenience init(from domain: BookSource) {
        let jsonString: String
        if let data = try? JSONEncoder().encode(domain),
           let str = String(data: data, encoding: .utf8) {
            jsonString = str
        } else {
            jsonString = "{}"
        }

        self.init(
            bookSourceUrl: domain.bookSourceUrl,
            bookSourceName: domain.bookSourceName,
            bookSourceGroup: domain.bookSourceGroup,
            bookSourceType: domain.bookSourceType ?? 0,
            enabled: domain.enabled ?? true,
            customOrder: domain.customOrder ?? 0,
            rawJson: jsonString)
    }

    public func toDomain() -> BookSource? {
        guard let data = rawJson.data(using: .utf8) else { return nil }
        var source = try? JSONDecoder().decode(BookSource.self, from: data)
        source?.enabled = self.enabled
        source?.customOrder = self.customOrder
        return source
    }
}
