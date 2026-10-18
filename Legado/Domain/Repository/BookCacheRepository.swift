import Foundation

/// 章节离线缓存数据仓库协议
public protocol BookCacheRepository: Sendable {
    /// 检查指定书籍的指定章节是否已缓存在磁盘
    func isChapterCached(bookUrl: String, index: Int) -> Bool

    /// 获取指定书籍已缓存的章节索引集合
    func getCachedChapterIndices(bookUrl: String) -> Set<Int>

    /// 读取已缓存的章节文本
    func getCachedChapterContent(bookUrl: String, index: Int) -> String?

    /// 写入章节内容至磁盘缓存
    func saveChapterContent(bookUrl: String, index: Int, content: String) throws

    /// 计算指定书籍占用的缓存字节数
    func calculateBookCacheSize(bookUrl: String) -> Int64

    /// 获取指定书籍的缓存详情
    func getBookCacheInfo(bookUrl: String, totalChapters: Int) -> BookCacheInfo

    /// 清空指定书籍的离线章节缓存
    func clearBookCache(bookUrl: String) throws

    /// 清空所有书籍的离线缓存
    func clearAllCache() throws

    /// 计算所有书籍占用的总缓存字节数
    func calculateTotalCacheSize() -> Int64
}
