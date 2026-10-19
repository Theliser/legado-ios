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

    /// 抓取并解析书籍详情信息
    public func fetchBookDetail(book: Book, source: BookSource) async throws -> Book {
        let requestInfo = try AnalyzeUrl(
            rawUrl: book.bookUrl,
            baseUrl: source.bookSourceUrl,
            headerJson: source.header,
            source: source,
            book: book)

        let responseBody = try await httpClient.fetch(analyzeUrl: requestInfo)
        var updatedBook = book
        guard let ruleInfo = source.ruleBookInfo else {
            return updatedBook
        }

        let baseUrl = requestInfo.url.absoluteString
        let analyzer = AnalyzeRule(book: updatedBook, source: source, baseUrl: baseUrl)
        analyzer.setContent(responseBody, baseUrl: baseUrl)

        if let initRule = ruleInfo.bookInfoInit, !initRule.isEmpty {
            if let initElement = analyzer.getElement(initRule) {
                analyzer.setContent(initElement, baseUrl: baseUrl)
            }
        }

        populateBookMetadata(analyzer: analyzer, ruleInfo: ruleInfo, book: &updatedBook)
        return updatedBook
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

    /// 抓取书籍全部章节目录（支持 nextTocUrl 自动分页抓取）
    public func fetchBookToc(book: Book, source: BookSource) async throws -> [Chapter] {
        let initialUrl = book.tocUrl.isEmpty ? book.bookUrl : book.tocUrl
        guard let ruleToc = source.ruleToc,
              let rawChapterListRule = ruleToc.chapterList,
              !rawChapterListRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var isReverse = false
        var chapterListRule = rawChapterListRule.trimmingCharacters(in: .whitespacesAndNewlines)
        if chapterListRule.hasPrefix("-") {
            isReverse = true
            chapterListRule = String(chapterListRule.dropFirst())
        } else if chapterListRule.hasPrefix("+") {
            chapterListRule = String(chapterListRule.dropFirst())
        }

        var chapters: [Chapter] = []
        var currentUrlString: String? = initialUrl
        var visitedUrls = Set<String>()
        var pageCount = 0
        let maxPages = 40

        while let targetUrlStr = currentUrlString, pageCount < maxPages {
            guard !visitedUrls.contains(targetUrlStr) else { break }
            visitedUrls.insert(targetUrlStr)
            pageCount += 1

            let (pageChapters, nextUrl) = try await fetchSingleTocPage(
                targetUrlStr: targetUrlStr,
                ruleToc: ruleToc,
                chapterListRule: chapterListRule,
                book: book,
                source: source)
            chapters.append(contentsOf: pageChapters)
            currentUrlString = nextUrl
        }

        if isReverse {
            chapters.reverse()
        }

        for index in chapters.indices {
            chapters[index].index = index
        }

        return chapters
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
