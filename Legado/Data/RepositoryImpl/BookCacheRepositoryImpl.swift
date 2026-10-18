import Foundation

/// 章节离线缓存数据仓库实现 (基于沙盒 Caches/LegadoChapters)
public final class BookCacheRepositoryImpl: BookCacheRepository, @unchecked Sendable {
    private let fileManager: FileManager
    private let baseDirectory: URL

    public init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            self.baseDirectory = caches.appendingPathComponent("LegadoChapters", isDirectory: true)
        }
    }

    public static func deterministicKey(for bookUrl: String) -> String {
        Data(bookUrl.utf8).map { String(format: "%02x", $0) }.joined()
    }

    private func bookDirectory(for bookUrl: String) -> URL {
        let key = Self.deterministicKey(for: bookUrl)
        return baseDirectory.appendingPathComponent(key, isDirectory: true)
    }

    private func chapterFileUrl(bookUrl: String, index: Int) -> URL {
        bookDirectory(for: bookUrl).appendingPathComponent("\(index).txt")
    }

    public func isChapterCached(bookUrl: String, index: Int) -> Bool {
        let url = chapterFileUrl(bookUrl: bookUrl, index: index)
        return fileManager.fileExists(atPath: url.path)
    }

    public func getCachedChapterIndices(bookUrl: String) -> Set<Int> {
        let dir = bookDirectory(for: bookUrl)
        guard let files = try? fileManager.contentsOfDirectory(atPath: dir.path) else {
            return []
        }

        var indices = Set<Int>()
        for file in files where file.hasSuffix(".txt") {
            let name = (file as NSString).deletingPathExtension
            if let idx = Int(name) {
                indices.insert(idx)
            }
        }
        return indices
    }

    public func getCachedChapterContent(bookUrl: String, index: Int) -> String? {
        let url = chapterFileUrl(bookUrl: bookUrl, index: index)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    public func saveChapterContent(bookUrl: String, index: Int, content: String) throws {
        let dir = bookDirectory(for: bookUrl)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileUrl = dir.appendingPathComponent("\(index).txt")
        try content.write(to: fileUrl, atomically: true, encoding: .utf8)
    }

    public func calculateBookCacheSize(bookUrl: String) -> Int64 {
        let dir = bookDirectory(for: bookUrl)
        guard let enumerator = fileManager.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    public func getBookCacheInfo(bookUrl: String, totalChapters: Int) -> BookCacheInfo {
        let cachedIndices = getCachedChapterIndices(bookUrl: bookUrl)
        let size = calculateBookCacheSize(bookUrl: bookUrl)
        return BookCacheInfo(
            bookUrl: bookUrl,
            cachedCount: cachedIndices.count,
            totalCount: totalChapters,
            sizeInBytes: size)
    }

    public func clearBookCache(bookUrl: String) throws {
        let dir = bookDirectory(for: bookUrl)
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
    }

    public func clearAllCache() throws {
        if fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.removeItem(at: baseDirectory)
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
    }

    public func calculateTotalCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
}
