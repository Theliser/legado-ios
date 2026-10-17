import Foundation

/// 章节正文多级缓存与抓取用例 (L1内存 -> L2磁盘 -> L3网络)
public final class GetChapterContentUseCase: @unchecked Sendable {
    private let sourceRepository: BookSourceRepository
    private let contentParser: ContentParser
    private let memoryCache = NSCache<NSString, NSString>()
    private let fileManager = FileManager.default

    public init(
        sourceRepository: BookSourceRepository,
        contentParser: ContentParser = .shared) {
        self.sourceRepository = sourceRepository
        self.contentParser = contentParser
    }

    /// 获取章节正文内容，自动走三级缓存体系
    public func execute(
        chapter: Chapter,
        origin: String,
        forceRefresh: Bool = false) async throws -> String {
        let cacheKey = "\(chapter.bookUrl)_\(chapter.index)" as NSString

        // 1. L1 内存缓存命中
        if !forceRefresh, let cachedMemory = memoryCache.object(forKey: cacheKey) {
            return cachedMemory as String
        }

        // 2. L2 磁盘持久化命中
        let diskUrl = getDiskCacheUrl(bookUrl: chapter.bookUrl, index: chapter.index)
        if !forceRefresh, fileManager.fileExists(atPath: diskUrl.path) {
            if let text = try? String(contentsOf: diskUrl, encoding: .utf8), !text.isEmpty {
                memoryCache.setObject(text as NSString, forKey: cacheKey)
                return text
            }
        }

        // 3. L3 网络抓取
        let sources = try await sourceRepository.fetchSources()
        guard let source = sources.first(where: { $0.bookSourceUrl == origin }) else {
            throw URLError(.resourceUnavailable)
        }

        let content = try await contentParser.fetchAndParseContent(
            chapterUrl: chapter.url,
            source: source,
            baseUrl: origin)

        // 写入 L1 内存与 L2 磁盘缓存
        memoryCache.setObject(content as NSString, forKey: cacheKey)
        saveToDisk(content: content, targetUrl: diskUrl)

        return content
    }

    /// 预加载下一章正文至本地缓存
    public func preload(chapter: Chapter, origin: String) {
        Task {
            _ = try? await self.execute(chapter: chapter, origin: origin, forceRefresh: false)
        }
    }

    /// 写入离线章节缓存
    public func saveChapterCache(content: String, bookUrl: String, index: Int) {
        let url = getDiskCacheUrl(bookUrl: bookUrl, index: index)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        let cacheKey = "\(bookUrl)_\(index)" as NSString
        memoryCache.setObject(content as NSString, forKey: cacheKey)
    }

    public static func deterministicKey(for bookUrl: String) -> String {
        Data(bookUrl.utf8).map { String(format: "%02x", $0) }.joined()
    }

    private func getDiskCacheUrl(bookUrl: String, index: Int) -> URL {
        let safeBookName = Self.deterministicKey(for: bookUrl)
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LegadoChapters", isDirectory: true)
            .appendingPathComponent(safeBookName, isDirectory: true)

        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(index).txt")
    }

    private func saveToDisk(content: String, targetUrl: URL) {
        Task.detached(priority: .background) {
            try? content.write(to: targetUrl, atomically: true, encoding: .utf8)
        }
    }
}
