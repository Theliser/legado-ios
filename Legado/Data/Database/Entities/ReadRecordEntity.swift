import Foundation
import SwiftData

/// SwiftData 阅读记录实体
@Model
public final class ReadRecordEntity {
    @Attribute(.unique) public var id: String
    public var bookName: String
    public var bookAuthor: String
    public var readTimeSeconds: Double
    public var lastReadDate: Date
    public var wordsRead: Int

    public init(
        id: String,
        bookName: String,
        bookAuthor: String,
        readTimeSeconds: Double = 0,
        lastReadDate: Date = Date(),
        wordsRead: Int = 0) {
        self.id = id
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.readTimeSeconds = readTimeSeconds
        self.lastReadDate = lastReadDate
        self.wordsRead = wordsRead
    }

    public convenience init(from domain: ReadRecord) {
        self.init(
            id: domain.id,
            bookName: domain.bookName,
            bookAuthor: domain.bookAuthor,
            readTimeSeconds: domain.readTimeSeconds,
            lastReadDate: domain.lastReadDate,
            wordsRead: domain.wordsRead)
    }

    public func toDomain() -> ReadRecord {
        ReadRecord(
            bookName: bookName,
            bookAuthor: bookAuthor,
            readTimeSeconds: readTimeSeconds,
            lastReadDate: lastReadDate,
            wordsRead: wordsRead)
    }
}
