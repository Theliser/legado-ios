import Foundation

/// 阅读时长与阅读历史领域模型
public struct ReadRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(bookName)_\(bookAuthor)"
    }

    public var bookName: String
    public var bookAuthor: String
    /// 累计阅读时间（秒）
    public var readTimeSeconds: TimeInterval
    /// 最近一次阅读时间
    public var lastReadDate: Date
    /// 累计阅读字数
    public var wordsRead: Int

    public init(
        bookName: String,
        bookAuthor: String,
        readTimeSeconds: TimeInterval = 0,
        lastReadDate: Date = Date(),
        wordsRead: Int = 0) {
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.readTimeSeconds = readTimeSeconds
        self.lastReadDate = lastReadDate
        self.wordsRead = wordsRead
    }
}
