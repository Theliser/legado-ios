import Foundation

/// 书籍书签与高亮笔记领域模型
public struct Bookmark: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(bookName)_\(bookAuthor)_\(time)"
    }

    /// 创建时间毫秒时间戳
    public let time: Int64
    /// 书籍名称
    public let bookName: String
    /// 书籍作者
    public let bookAuthor: String
    /// 书籍 URL (源指纹)
    public let bookUrl: String
    /// 章节索引
    public var chapterIndex: Int
    /// 章节内字符偏移量
    public var chapterPos: Int
    /// 章节标题
    public var chapterName: String
    /// 正文选段摘录
    public var bookText: String
    /// 读者批注/随笔随想
    public var content: String

    public init(
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        bookName: String,
        bookAuthor: String,
        bookUrl: String,
        chapterIndex: Int,
        chapterPos: Int,
        chapterName: String,
        bookText: String,
        content: String = "") {
        self.time = time
        self.bookName = bookName
        self.bookAuthor = bookAuthor
        self.bookUrl = bookUrl
        self.chapterIndex = chapterIndex
        self.chapterPos = chapterPos
        self.chapterName = chapterName
        self.bookText = bookText
        self.content = content
    }

    /// 格式化创建日期
    public var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(time) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
