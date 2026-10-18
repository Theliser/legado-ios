import Foundation

/// 书源全流程实时规则调试用例（搜索 -> 详情 -> 目录 -> 正文）
public final class DebugBookSourceUseCase: Sendable {
    private let searchService: SourceSearchService
    private let detailAndTocService: SourceDetailAndTocService
    private let contentParser: ContentParser

    public init(
        searchService: SourceSearchService = .shared,
        detailAndTocService: SourceDetailAndTocService = .shared,
        contentParser: ContentParser = .shared) {
        self.searchService = searchService
        self.detailAndTocService = detailAndTocService
        self.contentParser = contentParser
    }

    /// 执行书源全流程规则测试并产生实时诊断报告
    public func execute(source: BookSource, keyword: String) async -> SourceDebugReport {
        let startTime = Date()
        var logs: [SourceDebugLog] = []

        logs.append(SourceDebugLog(level: .info, message: "开始调试书源: \(source.bookSourceName)"))
        logs.append(SourceDebugLog(level: .info, message: "书源地址: \(source.bookSourceUrl)"))
        logs.append(SourceDebugLog(level: .info, message: "测试关键字: \(keyword)"))

        // --- STAGE 1: SEARCH ---
        guard let firstBook = await debugSearch(source: source, keyword: keyword, logs: &logs) else {
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            return SourceDebugReport(
                sourceName: source.bookSourceName,
                isSuccess: false,
                durationMs: elapsed,
                logs: logs)
        }

        // --- STAGE 2: DETAIL ---
        let sampleBook = await debugDetail(source: source, firstBook: firstBook, logs: &logs)

        // --- STAGE 3: TOC ---
        let chapters = await debugToc(source: source, sampleBook: sampleBook, logs: &logs)

        // --- STAGE 4: CONTENT ---
        await debugContent(source: source, firstChapter: chapters.first, tocUrl: sampleBook.tocUrl, logs: &logs)

        let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
        logs.append(SourceDebugLog(level: .success, message: "🎉 书源全流程调试完成，总耗时: \(elapsed)ms"))

        return SourceDebugReport(
            sourceName: source.bookSourceName,
            isSuccess: true,
            durationMs: elapsed,
            logs: logs,
            sampleResult: firstBook)
    }

    private func debugSearch(
        source: BookSource,
        keyword: String,
        logs: inout [SourceDebugLog]) async -> SearchResult? {
        logs.append(SourceDebugLog(level: .info, message: "─── [1/4 搜索阶段] ───"))
        guard let searchUrl = source.searchUrl, !searchUrl.isEmpty else {
            logs.append(SourceDebugLog(level: .error, message: "书源未配置 searchUrl"))
            return nil
        }
        logs.append(SourceDebugLog(level: .info, message: "搜索 URL: \(searchUrl)"))

        do {
            let results = try await searchService.search(source: source, keyword: keyword)
            guard let first = results.first else {
                logs.append(SourceDebugLog(level: .warning, message: "搜索成功但未解析出匹配书籍"))
                return nil
            }
            logs.append(SourceDebugLog(level: .success, message: "搜索成功: 共获取 \(results.count) 条结果"))
            logs.append(SourceDebugLog(level: .info, message: "样例: 《\(first.name)》 作者: \(first.author)"))
            logs.append(SourceDebugLog(level: .info, message: "详情 URL: \(first.bookUrl)"))
            return first
        } catch {
            logs.append(SourceDebugLog(level: .error, message: "搜索异常: \(error.localizedDescription)"))
            return nil
        }
    }

    private func debugDetail(
        source: BookSource,
        firstBook: SearchResult,
        logs: inout [SourceDebugLog]) async -> Book {
        logs.append(SourceDebugLog(level: .info, message: "─── [2/4 详情阶段] ───"))
        var book = Book(
            bookUrl: firstBook.bookUrl,
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: firstBook.name,
            author: firstBook.author,
            kind: firstBook.kind,
            coverUrl: firstBook.coverUrl,
            intro: firstBook.intro,
            latestChapterTitle: firstBook.latestChapterTitle,
            wordCount: firstBook.wordCount)

        guard source.ruleBookInfo != nil else {
            logs.append(SourceDebugLog(level: .info, message: "未配置 ruleBookInfo，沿用搜索结果"))
            return book
        }

        do {
            book = try await detailAndTocService.fetchBookDetail(book: book, source: source)
            logs.append(SourceDebugLog(level: .success, message: "详情解析成功"))
            if let intro = book.intro, !intro.isEmpty {
                let preview = intro.prefix(60).replacingOccurrences(of: "\n", with: " ")
                logs.append(SourceDebugLog(level: .info, message: "简介: \(preview)..."))
            }
            logs.append(SourceDebugLog(level: .info, message: "目录 URL: \(book.tocUrl)"))
        } catch {
            logs.append(SourceDebugLog(level: .warning, message: "详情解析失败: \(error.localizedDescription)"))
        }
        return book
    }

    private func debugToc(
        source: BookSource,
        sampleBook: Book,
        logs: inout [SourceDebugLog]) async -> [Chapter] {
        logs.append(SourceDebugLog(level: .info, message: "─── [3/4 目录阶段] ───"))
        guard source.ruleToc != nil else {
            logs.append(SourceDebugLog(level: .info, message: "未配置 ruleToc，跳过目录抓取"))
            return []
        }

        do {
            let chapters = try await detailAndTocService.fetchBookToc(book: sampleBook, source: source)
            if chapters.isEmpty {
                logs.append(SourceDebugLog(level: .warning, message: "目录解析结果为空"))
            } else {
                logs.append(SourceDebugLog(level: .success, message: "目录解析成功: 共 \(chapters.count) 章"))
                if let first = chapters.first {
                    logs.append(SourceDebugLog(level: .info, message: "首章: \(first.title)"))
                    logs.append(SourceDebugLog(level: .info, message: "首章 URL: \(first.url)"))
                }
            }
            return chapters
        } catch {
            logs.append(SourceDebugLog(level: .error, message: "目录抓取失败: \(error.localizedDescription)"))
            return []
        }
    }

    private func debugContent(
        source: BookSource,
        firstChapter: Chapter?,
        tocUrl: String,
        logs: inout [SourceDebugLog]) async {
        logs.append(SourceDebugLog(level: .info, message: "─── [4/4 正文阶段] ───"))
        guard let first = firstChapter, source.ruleContent != nil else {
            logs.append(SourceDebugLog(level: .info, message: "无首章或未配置 ruleContent，跳过正文"))
            return
        }

        do {
            let content = try await contentParser.fetchAndParseContent(
                chapterUrl: first.url,
                source: source,
                baseUrl: tocUrl)
            let charCount = content.count
            if charCount > 0 {
                logs.append(SourceDebugLog(level: .success, message: "正文抓取成功: 共 \(charCount) 字"))
                let preview = content.prefix(80).replacingOccurrences(of: "\n", with: " ")
                logs.append(SourceDebugLog(level: .info, message: "内容预览: \(preview)..."))
            } else {
                logs.append(SourceDebugLog(level: .warning, message: "正文抓取返回空文本"))
            }
        } catch {
            logs.append(SourceDebugLog(level: .error, message: "正文抓取失败: \(error.localizedDescription)"))
        }
    }
}
