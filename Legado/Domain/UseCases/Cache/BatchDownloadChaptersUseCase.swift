import Foundation

/// 离线章节并发批量下载用例 (支持快捷区间、AsyncSemaphore 并发度控制与进度汇报)
public final class BatchDownloadChaptersUseCase: Sendable {
    private let getChapterContentUseCase: GetChapterContentUseCase
    private let bookCacheRepository: BookCacheRepository

    public init(
        getChapterContentUseCase: GetChapterContentUseCase,
        bookCacheRepository: BookCacheRepository) {
        self.getChapterContentUseCase = getChapterContentUseCase
        self.bookCacheRepository = bookCacheRepository
    }

    /// 执行批量下载任务
    public func execute(
        book: Book,
        chapters: [Chapter],
        option: BatchDownloadOption,
        concurrency: Int = 3,
        onProgress: (@Sendable (BatchDownloadProgress) -> Void)? = nil) async throws {
        guard !chapters.isEmpty else { return }

        // 1. 根据选项计算目标章节范围
        let targetRange = calculateTargetRange(book: book, totalCount: chapters.count, option: option)
        let candidateChapters = chapters.filter { targetRange.contains($0.index) }

        // 2. 过滤已缓存的章节
        let uncachedChapters = candidateChapters.filter {
            !bookCacheRepository.isChapterCached(bookUrl: book.bookUrl, index: $0.index)
        }

        var progress = BatchDownloadProgress(
            bookUrl: book.bookUrl,
            bookName: book.name,
            totalChaptersToDownload: uncachedChapters.count,
            completedChaptersCount: 0,
            currentChapterTitle: nil,
            status: uncachedChapters.isEmpty ? .completed : .downloading)

        onProgress?(progress)

        guard !uncachedChapters.isEmpty else { return }

        // 3. 多通道并发安全下载
        let semaphore = AsyncSemaphore(value: max(1, concurrency))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for chapter in uncachedChapters {
                try Task.checkCancellation()

                group.addTask { [getChapterContentUseCase, book] in
                    try await semaphore.withPermit {
                        try Task.checkCancellation()
                        _ = try await getChapterContentUseCase.execute(
                            chapter: chapter,
                            origin: book.origin,
                            forceRefresh: false)
                    }
                }

                progress.completedChaptersCount += 1
                progress.currentChapterTitle = chapter.title
                onProgress?(progress)
            }

            try await group.waitForAll()
        }

        progress.status = .completed
        progress.currentChapterTitle = nil
        onProgress?(progress)
    }

    /// 计算目标章节索引范围
    public func calculateTargetRange(
        book: Book,
        totalCount: Int,
        option: BatchDownloadOption) -> ClosedRange<Int> {
        let currentIndex = max(0, min(book.durChapterIndex, totalCount - 1))
        let maxIndex = max(0, totalCount - 1)

        switch option {
        case .next50:
            let endIndex = min(maxIndex, currentIndex + 49)
            return currentIndex ... endIndex

        case .next100:
            let endIndex = min(maxIndex, currentIndex + 99)
            return currentIndex ... endIndex

        case .allUnread:
            return currentIndex ... maxIndex

        case .all:
            return 0 ... maxIndex
        }
    }
}
