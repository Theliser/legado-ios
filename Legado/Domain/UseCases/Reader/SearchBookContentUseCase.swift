import Foundation

/// 正文全文内容检索用例 (跨章节多段落关键词匹配与上下文提取)
public final class SearchBookContentUseCase: Sendable {
    public init() {}

    /// 流式并发检索指定全书章节内的关键词命中项
    public func search(
        keyword: String,
        book: Book,
        chapters: [Chapter],
        getChapterContentUseCase: GetChapterContentUseCase,
        maxMatches: Int = 200) -> AsyncStream<BookSearchMatch> {
        let cleanKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        return AsyncStream { continuation in
            let task = Task {
                guard !cleanKeyword.isEmpty, !chapters.isEmpty else {
                    continuation.finish()
                    return
                }

                var matchCount = 0

                for chapter in chapters {
                    if Task.isCancelled || matchCount >= maxMatches {
                        break
                    }

                    // 优先拉取缓存正文
                    guard let content = try? await getChapterContentUseCase.execute(
                        chapter: chapter,
                        origin: book.origin,
                        forceRefresh: false), !content.isEmpty else {
                        continue
                    }

                    let matches = extractMatches(
                        keyword: cleanKeyword,
                        content: content,
                        chapter: chapter)

                    for match in matches {
                        if Task.isCancelled || matchCount >= maxMatches {
                            break
                        }
                        continuation.yield(match)
                        matchCount += 1
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func extractMatches(
        keyword: String,
        content: String,
        chapter: Chapter) -> [BookSearchMatch] {
        var results: [BookSearchMatch] = []
        let nsContent = content as NSString
        var searchRange = NSRange(location: 0, length: nsContent.length)

        while searchRange.location < nsContent.length {
            let found = nsContent.range(
                of: keyword,
                options: .caseInsensitive,
                range: searchRange)

            if found.location == NSNotFound {
                break
            }

            // 截取前后上下文
            let prefixStart = max(0, found.location - 18)
            let suffixEnd = min(nsContent.length, found.location + found.length + 28)
            let snippetRange = NSRange(location: prefixStart, length: suffixEnd - prefixStart)
            var snippet = nsContent.substring(with: snippetRange)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: "")

            if prefixStart > 0 {
                snippet = "..." + snippet
            }
            if suffixEnd < nsContent.length {
                snippet += "..."
            }

            results.append(BookSearchMatch(
                chapterIndex: chapter.index,
                chapterTitle: chapter.title,
                snippet: snippet,
                matchOffset: found.location,
                matchLength: found.length))

            searchRange.location = found.location + max(found.length, 1)
            searchRange.length = nsContent.length - searchRange.location
        }

        return results
    }
}
