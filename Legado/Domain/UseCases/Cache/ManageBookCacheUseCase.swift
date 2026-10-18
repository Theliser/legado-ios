import Foundation

/// 离线缓存空间管理与清理用例
public final class ManageBookCacheUseCase: Sendable {
    private let bookCacheRepository: BookCacheRepository

    public init(bookCacheRepository: BookCacheRepository) {
        self.bookCacheRepository = bookCacheRepository
    }

    /// 获取单本书籍的缓存状态与空间占用
    public func getBookCacheInfo(bookUrl: String, totalChapters: Int) -> BookCacheInfo {
        bookCacheRepository.getBookCacheInfo(bookUrl: bookUrl, totalChapters: totalChapters)
    }

    /// 清空指定书籍的缓存
    public func clearBookCache(bookUrl: String) throws {
        try bookCacheRepository.clearBookCache(bookUrl: bookUrl)
    }

    /// 清空所有书籍的离线缓存
    public func clearAllCache() throws {
        try bookCacheRepository.clearAllCache()
    }

    /// 计算所有书籍占用的总离线缓存大小
    public func calculateTotalCacheSize() -> Int64 {
        bookCacheRepository.calculateTotalCacheSize()
    }
}
