import Foundation

/// 书源全流程实时规则调试用例（对齐 Legado Android：支持搜索/发现/详情/目录/正文多目标调试）
public final class DebugBookSourceUseCase: Sendable {
    private let searchService: SourceSearchService
    private let exploreService: SourceExploreService
    private let detailAndTocService: SourceDetailAndTocService
    private let contentParser: ContentParser

    public init(
        searchService: SourceSearchService = .shared,
        exploreService: SourceExploreService = .shared,
        detailAndTocService: SourceDetailAndTocService = .shared,
        contentParser: ContentParser = .shared) {
        self.searchService = searchService
        self.exploreService = exploreService
        self.detailAndTocService = detailAndTocService
        self.contentParser = contentParser
    }

    /// 根据书源配置生成快捷测试示例
    public func generateExamples(for source: BookSource) -> [SourceDebugExample] {
        var list: [SourceDebugExample] = []

        // 1. 搜索关键词示例
        let configuredKeyword = source.ruleSearch?.checkKeyWord?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainKeyword = (configuredKeyword?.isEmpty == false) ? configuredKeyword! : "斗罗大陆"
        list.append(SourceDebugExample(title: mainKeyword, target: .search, value: mainKeyword))
        list.append(SourceDebugExample(title: "系统", target: .search, value: "系统"))

        // 2. 发现分类示例
        let categories = exploreService.parseCategories(source: source)
        for cat in categories.prefix(4) {
            list.append(SourceDebugExample(title: cat.title, target: .explore, value: cat.categoryUrl))
        }

        return list
    }

    /// 便捷搜索调试入口
    public func execute(source: BookSource, keyword: String) async -> SourceDebugReport {
        await execute(source: source, target: .search, query: keyword)
    }

    /// 执行全流程或指定目标调试
    public func execute(
        source: BookSource,
        target: SourceDebugTarget = .search,
        query: String,
        onLog: (@Sendable (SourceDebugLog) -> Void)? = nil) async -> SourceDebugReport {
        let startTime = Date()
        var logs: [SourceDebugLog] = []

        let recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void = { level, msg, payload in
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            let log = SourceDebugLog(level: level, message: msg, elapsedMs: elapsed, payload: payload)
            logs.append(log)
            onLog?(log)
        }

        recordLog(.info, "开始调试书源: \(source.bookSourceName)", nil)
        recordLog(.info, "书源地址: \(source.bookSourceUrl)", nil)
        recordLog(.info, "调试目标: \(target.rawValue) | 输入值: \(query)", nil)

        let (isSuccess, sampleResult) = await runTargetPipeline(
            source: source,
            target: target,
            query: query,
            recordLog: recordLog)

        let totalElapsed = Int(Date().timeIntervalSince(startTime) * 1000)
        let finalStatus = isSuccess ? "🎉 调试完成 (通过)" : "❌ 调试中断 (未通过)"
        recordLog(isSuccess ? .success : .error, "\(finalStatus)，总耗时: \(totalElapsed)ms", nil)

        return SourceDebugReport(
            sourceName: source.bookSourceName,
            isSuccess: isSuccess,
            durationMs: totalElapsed,
            logs: logs,
            sampleResult: sampleResult)
    }

    private func runTargetPipeline(
        source: BookSource,
        target: SourceDebugTarget,
        query: String,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> (Bool, SearchResult?) {
        switch target {
        case .search:
            guard let (firstBook, sample) = await debugSearchStage(
                source: source,
                keyword: query,
                recordLog: recordLog) else {
                return (false, nil)
            }
            let success = await runFollowupStages(source: source, firstBook: firstBook, recordLog: recordLog)
            return (success, sample)

        case .explore:
            guard let firstBook = await debugExploreStage(
                source: source,
                categoryUrl: query,
                recordLog: recordLog) else {
                return (false, nil)
            }
            let sample = SearchResult(
                bookUrl: firstBook.bookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                originOrder: source.customOrder ?? 0,
                name: firstBook.name,
                author: firstBook.author,
                kind: firstBook.kind,
                coverUrl: firstBook.coverUrl,
                intro: firstBook.intro,
                latestChapterTitle: firstBook.latestChapterTitle,
                wordCount: firstBook.wordCount)
            let success = await runFollowupStages(source: source, firstBook: firstBook, recordLog: recordLog)
            return (success, sample)

        case .info:
            let dummy = Book(bookUrl: query, origin: source.bookSourceUrl, name: "调试书籍", author: "")
            let success = await runFollowupStages(source: source, firstBook: dummy, recordLog: recordLog)
            return (success, nil)

        case .toc:
            let dummy = Book(bookUrl: "", tocUrl: query, origin: source.bookSourceUrl, name: "调试书籍", author: "")
            guard let firstChapter = await debugTocStage(source: source, sampleBook: dummy, recordLog: recordLog) else {
                return (false, nil)
            }
            let success = await debugContentStage(source: source, chapterUrl: firstChapter.url, recordLog: recordLog)
            return (success, nil)

        case .content:
            let success = await debugContentStage(source: source, chapterUrl: query, recordLog: recordLog)
            return (success, nil)
        }
    }

    private func runFollowupStages(
        source: BookSource,
        firstBook: Book,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> Bool {
        let sampleBook = await debugDetailStage(source: source, book: firstBook, recordLog: recordLog)
        guard let firstChapter = await debugTocStage(
            source: source,
            sampleBook: sampleBook,
            recordLog: recordLog) else {
            return false
        }
        return await debugContentStage(source: source, chapterUrl: firstChapter.url, recordLog: recordLog)
    }

    // MARK: - 各阶段具体调试逻辑

    private func debugSearchStage(
        source: BookSource,
        keyword: String,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> (Book, SearchResult)? {
        recordLog(.info, "─── [1/4 搜索阶段] ───", nil)
        guard let searchUrl = source.searchUrl, !searchUrl.isEmpty else {
            recordLog(.error, "书源未配置 searchUrl", nil)
            return nil
        }
        recordLog(.info, "搜索 URL 规则: \(searchUrl)", nil)

        do {
            let results = try await searchService.search(source: source, keyword: keyword)
            guard let first = results.first else {
                recordLog(.warning, "搜索完成但未匹配到书籍", nil)
                return nil
            }
            recordLog(.success, "搜索成功: 共获取 \(results.count) 条结果", nil)
            recordLog(.info, "样例: 《\(first.name)》 作者: \(first.author)", nil)
            recordLog(.info, "详情 URL: \(first.bookUrl)", nil)
            let book = Book(
                bookUrl: first.bookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                name: first.name,
                author: first.author,
                kind: first.kind,
                coverUrl: first.coverUrl,
                intro: first.intro,
                latestChapterTitle: first.latestChapterTitle,
                wordCount: first.wordCount)
            return (book, first)
        } catch {
            recordLog(.error, "搜索请求失败: \(error.localizedDescription)", nil)
            return nil
        }
    }

    private func debugExploreStage(
        source: BookSource,
        categoryUrl: String,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> Book? {
        recordLog(.info, "─── [发现阶段] ───", nil)
        let category = ExploreCategory(
            sourceUrl: source.bookSourceUrl,
            sourceName: source.bookSourceName,
            title: "调试分类",
            categoryUrl: categoryUrl)
        do {
            let books = try await exploreService.fetchExploreBooks(source: source, category: category, page: 1)
            guard let first = books.first else {
                recordLog(.warning, "发现页解析为空", nil)
                return nil
            }
            recordLog(.success, "发现页抓取成功: 共获取 \(books.count) 本书籍", nil)
            recordLog(.info, "样例: 《\(first.name)》 | 详情 URL: \(first.bookUrl)", nil)
            return first
        } catch {
            recordLog(.error, "发现抓取失败: \(error.localizedDescription)", nil)
            return nil
        }
    }

    private func debugDetailStage(
        source: BookSource,
        book: Book,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> Book {
        recordLog(.info, "─── [2/4 详情阶段] ───", nil)
        guard source.ruleBookInfo != nil else {
            recordLog(.info, "未配置 ruleBookInfo，跳过详情抓取", nil)
            return book
        }

        do {
            let updated = try await detailAndTocService.fetchBookDetail(book: book, source: source)
            recordLog(.success, "详情解析成功", nil)
            if let intro = updated.intro, !intro.isEmpty {
                let preview = intro.prefix(80).replacingOccurrences(of: "\n", with: " ")
                recordLog(.info, "简介: \(preview)...", intro)
            }
            recordLog(.info, "目录 URL: \(updated.tocUrl)", nil)
            return updated
        } catch {
            recordLog(.warning, "详情解析异常: \(error.localizedDescription)，沿用原数据", nil)
            return book
        }
    }

    private func debugTocStage(
        source: BookSource,
        sampleBook: Book,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> Chapter? {
        recordLog(.info, "─── [3/4 目录阶段] ───", nil)
        guard source.ruleToc != nil else {
            recordLog(.info, "未配置 ruleToc，跳过目录抓取", nil)
            return nil
        }

        do {
            let chapters = try await detailAndTocService.fetchBookToc(book: sampleBook, source: source)
            guard let first = chapters.first else {
                recordLog(.warning, "目录解析结果为空", nil)
                return nil
            }
            recordLog(.success, "目录解析成功: 共 \(chapters.count) 个章节", nil)
            recordLog(.info, "首章: \(first.title)", nil)
            recordLog(.info, "首章 URL: \(first.url)", nil)
            return first
        } catch {
            recordLog(.error, "目录抓取失败: \(error.localizedDescription)", nil)
            return nil
        }
    }

    private func debugContentStage(
        source: BookSource,
        chapterUrl: String,
        recordLog: @Sendable (SourceDebugLog.LogLevel, String, String?) -> Void) async -> Bool {
        recordLog(.info, "─── [4/4 正文阶段] ───", nil)
        guard source.ruleContent != nil else {
            recordLog(.info, "未配置 ruleContent，跳过正文测试", nil)
            return true
        }

        do {
            let content = try await contentParser.fetchAndParseContent(
                chapterUrl: chapterUrl,
                source: source,
                baseUrl: source.bookSourceUrl)
            let count = content.count
            if count > 0 {
                recordLog(.success, "正文抓取成功: 共 \(count) 字", content)
                let preview = content.prefix(100).replacingOccurrences(of: "\n", with: " ")
                recordLog(.info, "正文预览: \(preview)...", nil)
                return true
            } else {
                recordLog(.warning, "正文抓取返回空内容", nil)
                return false
            }
        } catch {
            recordLog(.error, "正文抓取失败: \(error.localizedDescription)", nil)
            return false
        }
    }
}
