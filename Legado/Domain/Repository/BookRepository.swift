import Foundation

/// 书架与书籍数据持久化仓储协议
public protocol BookRepository: Sendable {
    /// 获取书架所有书籍
    func getBookshelf() async throws -> [Book]

    /// 根据详情 URL 查询书籍
    func getBook(by url: String) async throws -> Book?

    /// 保存或更新书籍到书架
    func saveBook(_ book: Book) async throws

    /// 从书架移除书籍
    func removeBook(by url: String) async throws

    /// 获取某书籍的所有目录章节
    func getChapters(for bookUrl: String) async throws -> [Chapter]

    /// 批量保存某书籍的目录章节
    func saveChapters(_ chapters: [Chapter], for bookUrl: String) async throws

    /// 获取书籍阅读记录
    func getReadRecord(bookName: String, bookAuthor: String) async throws -> ReadRecord?

    /// 更新或保存阅读记录
    func saveReadRecord(_ record: ReadRecord) async throws
}
