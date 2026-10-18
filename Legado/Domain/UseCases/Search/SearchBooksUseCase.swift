import Foundation

/// 搜索进度与流式事件
public enum SearchProgressEvent: Sendable {
    /// 搜索开始，返回参与并发搜索的书源总数
    case started(totalSources: Int)
    /// 某个书源搜索完成并返回结果
    case sourceFinished(sourceName: String, results: [SearchResult], elapsedMs: Int)
    /// 某个书源发生网络或解析错误
    case sourceFailed(sourceName: String, error: String)
    /// 所有书源执行完毕，返回完整聚合去重后的结果列表
    case allCompleted(groups: [SearchResultGroup])
}

private struct SourceSearchResult: Sendable {
    let sourceName: String
    let results: [SearchResult]
    let elapsedMs: Int
}

private enum SourceSearchTaskResult: Sendable {
    case success(SourceSearchResult)
    case failure(sourceName: String, error: String)
}

/// 多书源并发聚合搜索用例（纯业务逻辑，不依赖 SwiftUI/UIKit）
public final class SearchBooksUseCase: Sendable {
    private let sourceRepository: BookSourceRepository
    private let searchService: SourceSearchService
    private let semaphore: AsyncSemaphore

    public init(
        sourceRepository: BookSourceRepository,
        searchService: SourceSearchService = .shared,
        maxConcurrency: Int = 6) {
        self.sourceRepository = sourceRepository
        self.searchService = searchService
        self.semaphore = AsyncSemaphore(value: maxConcurrency)
    }

    /// 以 AsyncStream 流式产出搜索进度与增量结果
    public func execute(keyword: String, page: Int = 1) -> AsyncStream<SearchProgressEvent> {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        return AsyncStream { continuation in
            let task = Task {
                guard !trimmedKeyword.isEmpty,
                      let sources = try? await sourceRepository.fetchEnabledSources(),
                      !sources.isEmpty else {
                    continuation.yield(.allCompleted(groups: []))
                    continuation.finish()
                    return
                }

                LegadoLog.ruleEngine.info("开始多书源并发搜索，关键词: [\(trimmedKeyword)], 参与书源: \(sources.count) 个")
                continuation.yield(.started(totalSources: sources.count))

                let allResults = await performSearchGroup(
                    sources: sources,
                    keyword: trimmedKeyword,
                    page: page,
                    continuation: continuation)

                let aggregated = aggregateAndSort(results: allResults, keyword: trimmedKeyword)
                LegadoLog.ruleEngine.info("多书源搜索结束，原始条目: \(allResults.count), 聚合去重后: \(aggregated.count) 本")
                continuation.yield(.allCompleted(groups: aggregated))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func performSearchGroup(
        sources: [BookSource],
        keyword: String,
        page: Int,
        continuation: AsyncStream<SearchProgressEvent>.Continuation) async -> [SearchResult] {
        var allResults: [SearchResult] = []

        await withTaskGroup(of: SourceSearchTaskResult.self) { group in
            for source in sources {
                group.addTask {
                    let start = CFAbsoluteTimeGetCurrent()
                    do {
                        let results = try await self.semaphore.withPermit {
                            try await self.searchService.search(
                                source: source,
                                keyword: keyword,
                                page: page)
                        }
                        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                        let sourceName = source.bookSourceName
                        LegadoLog.ruleEngine.debug("书源 [\(sourceName)] 搜索耗时 \(elapsedMs)ms，命中 \(results.count) 条")
                        let searchResult = SourceSearchResult(
                            sourceName: sourceName,
                            results: results,
                            elapsedMs: elapsedMs)
                        return .success(searchResult)
                    } catch {
                        let sourceName = source.bookSourceName
                        LegadoLog.ruleEngine.warning("书源 [\(sourceName)] 搜索失败: \(error.localizedDescription)")
                        return .failure(sourceName: sourceName, error: error.localizedDescription)
                    }
                }
            }

            for await result in group {
                if Task.isCancelled {
                    break
                }
                switch result {
                case let .success(item):
                    allResults.append(contentsOf: item.results)
                    continuation.yield(.sourceFinished(
                        sourceName: item.sourceName,
                        results: item.results,
                        elapsedMs: item.elapsedMs))

                case let .failure(sourceName, error):
                    continuation.yield(.sourceFailed(
                        sourceName: sourceName,
                        error: error))
                }
            }
        }

        return allResults
    }

    /// 将各个书源返回的散列搜索项按「书名 + 作者」聚合去重
    public func aggregateAndSort(results: [SearchResult], keyword: String) -> [SearchResultGroup] {
        var groupDict: [String: SearchResultGroup] = [:]

        for item in results {
            let bookName = item.name.trimmingCharacters(in: .whitespaces)
            let bookAuthor = item.author.trimmingCharacters(in: .whitespaces)
            let key = "\(bookName)::\(bookAuthor)"

            if var existing = groupDict[key] {
                existing.sources.append(item)
                // 补充更丰富的封面或简介
                let noCover = existing.coverUrl == nil || existing.coverUrl?.isEmpty == true
                if noCover, let cover = item.coverUrl, !cover.isEmpty {
                    existing.coverUrl = cover
                }
                let noIntro = existing.intro == nil || existing.intro?.isEmpty == true
                if noIntro, let intro = item.intro, !intro.isEmpty {
                    existing.intro = intro
                }
                if existing.latestChapterTitle == nil, let latest = item.latestChapterTitle, !latest.isEmpty {
                    existing.latestChapterTitle = latest
                }
                groupDict[key] = existing
            } else {
                groupDict[key] = SearchResultGroup(
                    name: item.name,
                    author: item.author,
                    coverUrl: item.coverUrl,
                    intro: item.intro,
                    kind: item.kind,
                    latestChapterTitle: item.latestChapterTitle,
                    sources: [item])
            }
        }

        return sortGroups(groupDict.values, keyword: keyword)
    }

    private func sortGroups(_ groups: some Collection<SearchResultGroup>, keyword: String) -> [SearchResultGroup] {
        groups.sorted { first, second in
            let firstExact = first.name == keyword
            let secondExact = second.name == keyword
            if firstExact != secondExact {
                return firstExact && !secondExact
            }

            let firstContains = first.name.contains(keyword)
            let secondContains = second.name.contains(keyword)
            if firstContains != secondContains {
                return firstContains && !secondContains
            }

            return first.sources.count > second.sources.count
        }
    }
}
