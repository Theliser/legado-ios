import Foundation

/// 章节正文多级缓存与抓取用例 (L1内存 -> L2磁盘 -> L3网络)
public final class GetChapterContentUseCase: @unchecked Sendable {
    private let sourceRepository: BookSourceRepository
    private let cacheRepository: BookCacheRepository
    private let contentParser: ContentParser
    private let memoryCache = NSCache<NSString, NSString>()

    public init(
        sourceRepository: BookSourceRepository,
        cacheRepository: BookCacheRepository = BookCacheRepositoryImpl(),
        contentParser: ContentParser = .shared) {
        self.sourceRepository = sourceRepository
        self.cacheRepository = cacheRepository
        self.contentParser = contentParser
    }

    /// 获取章节正文内容，自动走三级缓存体系 (L1内存 -> L2磁盘 -> L3网络)
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
        if !forceRefresh, let diskContent = cacheRepository.getCachedChapterContent(
            bookUrl: chapter.bookUrl,
            index: chapter.index), !diskContent.isEmpty {
            memoryCache.setObject(diskContent as NSString, forKey: cacheKey)
            return diskContent
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
        try? cacheRepository.saveChapterContent(bookUrl: chapter.bookUrl, index: chapter.index, content: content)

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
        try? cacheRepository.saveChapterContent(bookUrl: bookUrl, index: index, content: content)
        let cacheKey = "\(bookUrl)_\(index)" as NSString
        memoryCache.setObject(content as NSString, forKey: cacheKey)
    }

    /// 判断指定章节是否已缓存在磁盘
    public func isChapterCached(bookUrl: String, index: Int) -> Bool {
        cacheRepository.isChapterCached(bookUrl: bookUrl, index: index)
    }
}
