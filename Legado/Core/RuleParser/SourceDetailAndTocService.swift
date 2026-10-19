import Foundation
import SwiftSoup

/// 负责书籍详情页与目录 (TOC) 的抓取与规则解析服务 (全面集成 AnalyzeUrl 与 JS 规则引擎)
public final class SourceDetailAndTocService: Sendable {
    public static let shared = SourceDetailAndTocService()

    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    // MARK: - 书籍详情解析

    /// 抓取并解析书籍详情信息 (全面通过 WebBook 统一中枢执行)
    public func fetchBookDetail(book: Book, source: BookSource) async throws -> Book {
        var mutableBook = book
        return try await WebBook.getBookInfoAwait(
            bookSource: source,
            book: &mutableBook,
            canReName: true,
            httpClient: httpClient)
    }

    private func populateBookMetadata(analyzer: AnalyzeRule, ruleInfo: RuleBookInfo, book: inout Book) {
        let name = analyzer.getString(ruleInfo.name)
        if !name.isEmpty {
            book.name = name
        }

        let author = analyzer.getString(ruleInfo.author)
        if !author.isEmpty {
            book.author = author
        }

        let cover = analyzer.getString(ruleInfo.coverUrl, isUrl: true)
        if !cover.isEmpty {
            book.coverUrl = cover
        }

        let intro = analyzer.getString(ruleInfo.intro)
        if !intro.isEmpty {
            book.intro = intro
        }

        let kind = analyzer.getString(ruleInfo.kind)
        if !kind.isEmpty {
            book.kind = kind
        }

        let lastChapter = analyzer.getString(ruleInfo.lastChapter)
        if !lastChapter.isEmpty {
            book.latestChapterTitle = lastChapter
            book.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
        }

        let wordCount = analyzer.getString(ruleInfo.wordCount)
        if !wordCount.isEmpty {
            book.wordCount = wordCount
        }

        let toc = analyzer.getString(ruleInfo.tocUrl, isUrl: true)
        if !toc.isEmpty {
            book.tocUrl = toc
        } else if book.tocUrl.isEmpty {
            book.tocUrl = book.bookUrl
        }
    }

    // MARK: - 目录 (TOC) 解析

    /// 抓取书籍全部章节目录（全面通过 WebBook 统一中枢执行，支持 preUpdateJs 与自动分页）
    public func fetchBookToc(book: Book, source: BookSource) async throws -> [Chapter] {
        try await WebBook.getChapterListAwait(
            bookSource: source,
            book: book,
            runPreJs: true,
            httpClient: httpClient)
    }

    private func fetchSingleTocPage(
        targetUrlStr: String,
        ruleToc: RuleToc,
        chapterListRule: String,
        book: Book,
        source: BookSource) async throws -> ([Chapter], String?) {
        let requestInfo = try AnalyzeUrl(
            rawUrl: targetUrlStr,
            baseUrl: source.bookSourceUrl,
            headerJson: source.header,
            source: source,
            book: book)

        let responseBody = try await httpClient.fetch(analyzeUrl: requestInfo)

        let baseUrl = requestInfo.url.absoluteString
        let analyzer = AnalyzeRule(book: book, source: source, baseUrl: baseUrl)
        analyzer.setContent(responseBody, baseUrl: baseUrl)

        let elements = analyzer.getElements(chapterListRule)
        var chapters: [Chapter] = []

        let nameRule = ruleToc.chapterName ?? "text"
        let urlRule = ruleToc.chapterUrl ?? "@href"

        for (index, element) in elements.enumerated() {
            let itemAnalyzer = AnalyzeRule(book: book, source: source, baseUrl: baseUrl)
            itemAnalyzer.setContent(element, baseUrl: baseUrl)

            let title = itemAnalyzer.getString(nameRule)
            guard !title.isEmpty else { continue }

            let url = itemAnalyzer.getString(urlRule, isUrl: true)
            guard !url.isEmpty else { continue }

            chapters.append(Chapter(
                url: url,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                bookUrl: book.bookUrl,
                index: index))
        }

        let nextUrl = ruleToc.nextTocUrl.flatMap { ruleStr -> String? in
            guard !ruleStr.isEmpty else { return nil }
            let next = analyzer.getString(ruleStr, isUrl: true)
            return next.isEmpty ? nil : next
        }

        return (chapters, nextUrl)
    }
}
