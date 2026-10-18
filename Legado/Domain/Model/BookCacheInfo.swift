import Foundation

/// 书籍离线缓存信息实体
public struct BookCacheInfo: Equatable, Sendable, Identifiable {
    public var id: String {
        bookUrl
    }

    public let bookUrl: String
    public let cachedCount: Int
    public let totalCount: Int
    public let sizeInBytes: Int64

    public init(
        bookUrl: String,
        cachedCount: Int,
        totalCount: Int,
        sizeInBytes: Int64) {
        self.bookUrl = bookUrl
        self.cachedCount = cachedCount
        self.totalCount = totalCount
        self.sizeInBytes = sizeInBytes
    }

    /// 格式化缓存大小显示（例如 "1.2 MB", "450 KB"）
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    /// 缓存完成百分比 (0 - 100)
    public var percentage: Int {
        guard totalCount > 0 else { return 0 }
        return min(100, Int((Double(cachedCount) / Double(totalCount)) * 100))
    }
}
