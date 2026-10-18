import Foundation

/// 换源结果数据结构
public struct SwitchSourceResult: Sendable {
    public let updatedBook: Book
    public let newToc: [Chapter]
    public let matchedChapterIndex: Int

    public init(updatedBook: Book, newToc: [Chapter], matchedChapterIndex: Int) {
        self.updatedBook = updatedBook
        self.newToc = newToc
        self.matchedChapterIndex = matchedChapterIndex
    }
}

/// 多源一键换源业务用例 (聚合并发检索、目录重映射与平滑迁移)
public final class ChangeBookSourceUseCase: Sendable {
    private let sourceRepository: BookSourceRepository
    private let bookRepository: BookRepository
    private let searchService: SourceSearchService
    private let tocService: SourceDetailAndTocService
    private let semaphore: AsyncSemaphore

    public init(
        sourceRepository: BookSourceRepository,
        bookRepository: BookRepository,
        searchService: SourceSearchService = .shared,
        tocService: SourceDetailAndTocService = .shared,
        maxConcurrency: Int = 6) {
        self.sourceRepository = sourceRepository
        self.bookRepository = bookRepository
        self.searchService = searchService
        self.tocService = tocService
        self.semaphore = AsyncSemaphore(value: maxConcurrency)
    }

    /// 针对指定书籍并发检索所有启用的可用候选书源 (流式实时产出)
    public func searchCandidates(for book: Book) -> AsyncStream<ChangeSourceCandidate> {
        let cleanName = book.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAuthor = book.author.trimmingCharacters(in: .whitespacesAndNewlines)

        return AsyncStream { continuation in
            let task = Task {
                guard let sources = try? await sourceRepository.fetchEnabledSources(), !sources.isEmpty else {
                    continuation.finish()
                    return
                }

                await withTaskGroup(of: ChangeSourceCandidate?.self) { group in
                    for source in sources {
                        group.addTask {
                            let start = CFAbsoluteTimeGetCurrent()
                            do {
                                let results = try await self.semaphore.withPermit {
                                    try await self.searchService.search(source: source, keyword: cleanName, page: 1)
                                }
                                let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

                                // 严格/模糊匹配同名同作者书籍
                                guard let matched = results.first(where: { item in
                                    let sameName = item.name.contains(cleanName) || cleanName.contains(item.name)
                                    let sameAuthor = cleanAuthor.isEmpty
                                        || item.author.contains(cleanAuthor)
                                        || cleanAuthor.contains(item.author)
                                    return sameName && sameAuthor
                                }) else {
                                    return nil
                                }

                                return ChangeSourceCandidate(
                                    origin: source.bookSourceUrl,
                                    originName: source.bookSourceName,
                                    bookUrl: matched.bookUrl,
                                    name: matched.name,
                                    author: matched.author,
                                    latestChapterTitle: matched.latestChapterTitle,
                                    coverUrl: matched.coverUrl,
                                    elapsedMs: elapsed,
                                    isCurrent: source.bookSourceUrl == book.origin)
                            } catch {
                                return nil
                            }
                        }
                    }

                    for await candidate in group {
                        if Task.isCancelled {
                            break
                        }
                        if let candidate {
                            continuation.yield(candidate)
                        }
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 执行换源：加载新源目录、精确匹配当前阅读章节进度并持久化
    public func switchSource(
        target: ChangeSourceCandidate,
        currentBook: Book,
        currentChapterTitle: String?,
        currentChapterIndex: Int) async throws -> SwitchSourceResult {
        let sources = try await sourceRepository.fetchSources()
        guard let targetSource = sources.first(where: { $0.bookSourceUrl == target.origin }) else {
            throw URLError(.resourceUnavailable)
        }

        // 构造临时目标书籍实体用于拉取目录
        var targetBook = currentBook
        targetBook.bookUrl = target.bookUrl
        targetBook.origin = target.origin
        targetBook.originName = target.originName
        if let cover = target.coverUrl, !cover.isEmpty {
            targetBook.coverUrl = cover
        }

        // 远程获取新书源目录
        let newToc = try await tocService.fetchBookToc(book: targetBook, source: targetSource)
        guard !newToc.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        // 计算新目录的最佳匹配章节索引
        let matchedIndex = matchChapterIndex(
            targetToc: newToc,
            currentTitle: currentChapterTitle ?? currentBook.durChapterTitle,
            currentIndex: currentChapterIndex)

        let matchedChapter = newToc[matchedIndex]

        // 组装最终换源后的书籍领域模型
        targetBook.durChapterIndex = matchedIndex
        targetBook.durChapterTitle = matchedChapter.title
        targetBook.durChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
        targetBook.totalChapterNum = newToc.count
        if let last = newToc.last {
            targetBook.latestChapterTitle = last.title
            targetBook.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
        }

        // 保存新书与对应目录至数据库
        try await bookRepository.saveBook(targetBook)
        try await bookRepository.saveChapters(newToc, for: targetBook.bookUrl)

        return SwitchSourceResult(
            updatedBook: targetBook,
            newToc: newToc,
            matchedChapterIndex: matchedIndex)
    }

    /// 智能章节匹配算法 (标题全等 -> 标题包含 -> 章节数字提取 -> 索引截断)
    public func matchChapterIndex(
        targetToc: [Chapter],
        currentTitle: String?,
        currentIndex: Int) -> Int {
        guard !targetToc.isEmpty else { return 0 }

        if let rawTitle = currentTitle, !rawTitle.isEmpty {
            let cleanCurrent = cleanTitle(rawTitle)

            // 1. 清洗后标题完全一致
            if let exactIndex = targetToc.firstIndex(where: { cleanTitle($0.title) == cleanCurrent }) {
                return exactIndex
            }

            // 2. 标题包含匹配
            if let containsIndex = targetToc.firstIndex(where: {
                let cleanTarget = cleanTitle($0.title)
                return cleanTarget.contains(cleanCurrent) || cleanCurrent.contains(cleanTarget)
            }) {
                return containsIndex
            }

            // 3. 正则提取章节序号对比 (如 "第123章" -> 123)
            if let currentNum = extractChapterNumber(rawTitle) {
                if let numIndex = targetToc.firstIndex(where: { extractChapterNumber($0.title) == currentNum }) {
                    return numIndex
                }
            }
        }

        // 4. 兜底策略：沿用旧索引并截断在合法边界内
        return min(max(currentIndex, 0), targetToc.count - 1)
    }

    private func cleanTitle(_ title: String) -> String {
        title.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: "\u{3000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractChapterNumber(_ title: String) -> Int? {
        let pattern = "第\\s*(\\d+)\\s*[章回节卷]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: title, range: NSRange(location: 0, length: title.utf16.count)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        return Int(title[range])
    }
}
