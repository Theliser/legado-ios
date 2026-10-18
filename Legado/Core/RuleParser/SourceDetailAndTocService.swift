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

        let responseBody = try await httpClient.get(url: requestInfo.url, headers: requestInfo.headers)
        let trimmed = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)

        var updatedBook = book
        guard let ruleInfo = source.ruleBookInfo else {
            return updatedBook
        }

        let isJson = trimmed.starts(with: "{") || trimmed.starts(with: "[")
        if isJson {
            parseJsonDetail(json: trimmed, rule: ruleInfo, book: &updatedBook, source: source)
        } else {
            parseHtmlDetail(html: responseBody, rule: ruleInfo, book: &updatedBook, baseUrl: book.bookUrl)
        }

        return updatedBook
    }

    private func parseHtmlDetail(html: String, rule: RuleBookInfo, book: inout Book, baseUrl: String) {
        guard let doc = try? SwiftSoup.parse(html, baseUrl) else { return }

        if let ruleName = rule.name, !ruleName.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleName, baseUrl: baseUrl), !val.isEmpty {
            book.name = val
        }
        if let ruleAuthor = rule.author, !ruleAuthor.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleAuthor, baseUrl: baseUrl), !val.isEmpty {
            book.author = val
        }
        if let ruleCover = rule.coverUrl, !ruleCover.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleCover, baseUrl: baseUrl), !val.isEmpty {
            book.coverUrl = resolveUrl(val, baseUrl: baseUrl)
        }
        if let ruleIntro = rule.intro, !ruleIntro.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleIntro, baseUrl: baseUrl), !val.isEmpty {
            book.intro = val
        }
        if let ruleKind = rule.kind, !ruleKind.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleKind, baseUrl: baseUrl), !val.isEmpty {
            book.kind = val
        }
        if let ruleLastChapter = rule.lastChapter, !ruleLastChapter.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleLastChapter, baseUrl: baseUrl),
           !val.isEmpty {
            book.latestChapterTitle = val
            book.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
        }
        if let ruleWord = rule.wordCount, !ruleWord.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleWord, baseUrl: baseUrl), !val.isEmpty {
            book.wordCount = val
        }
        if let ruleToc = rule.tocUrl, !ruleToc.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: ruleToc, baseUrl: baseUrl), !val.isEmpty {
            book.tocUrl = resolveUrl(val, baseUrl: baseUrl)
        } else if book.tocUrl.isEmpty {
            book.tocUrl = book.bookUrl
        }
    }

    private func parseJsonDetail(json: String, rule: RuleBookInfo, book: inout Book, source: BookSource) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let targetDict = extractInitDict(from: root, initRule: rule.bookInfoInit)
        applyJsonDetailFields(dict: targetDict, rule: rule, book: &book, source: source)
    }

    private func extractInitDict(from root: [String: Any], initRule: String?) -> [String: Any] {
        guard let initRule, !initRule.isEmpty else { return root }
        let initKey = initRule.replacingOccurrences(of: "$.", with: "").trimmingCharacters(in: .whitespaces)
        return (root[initKey] as? [String: Any]) ?? root
    }

    private func applyJsonDetailFields(
        dict: [String: Any],
        rule: RuleBookInfo,
        book: inout Book,
        source: BookSource) {
        let eval: (String?) -> String? = { ruleStr in
            RuleEvaluator.evaluate(dict: dict, rule: ruleStr, baseUrl: source.bookSourceUrl)
        }

        book.name = eval(rule.name) ?? book.name
        book.author = eval(rule.author) ?? book.author
        if let cover = eval(rule.coverUrl) {
            book.coverUrl = resolveUrl(cover, baseUrl: source.bookSourceUrl)
        }
        book.intro = eval(rule.intro) ?? book.intro
        book.kind = eval(rule.kind) ?? book.kind
        if let lastChapter = eval(rule.lastChapter) {
            book.latestChapterTitle = lastChapter
            book.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
        }
        book.wordCount = eval(rule.wordCount) ?? book.wordCount
        if let toc = eval(rule.tocUrl) {
            book.tocUrl = resolveUrl(toc, baseUrl: source.bookSourceUrl)
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

        let responseBody: String
        if requestInfo.method == "POST" {
            responseBody = try await httpClient.post(
                url: requestInfo.url,
                body: requestInfo.body,
                headers: requestInfo.headers)
        } else {
            responseBody = try await httpClient.get(
                url: requestInfo.url,
                headers: requestInfo.headers)
        }

        let trimmed = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let isJson = trimmed.starts(with: "{") || trimmed.starts(with: "[") || chapterListRule.contains("<js>")

        if isJson {
            let context = TocContext(baseUrl: targetUrlStr, source: source, book: book)
            let pageChapters = parseJsonTocPage(
                json: trimmed,
                rule: ruleToc,
                listRule: chapterListRule,
                context: context)
            var nextUrl: String?
            if let nextRule = ruleToc.nextTocUrl, !nextRule.isEmpty,
               let next = JSONPathParser.parse(json: trimmed, path: nextRule).first, !next.isEmpty {
                nextUrl = resolveUrl(next, baseUrl: targetUrlStr)
            }
            return (pageChapters, nextUrl)
        } else {
            return parseHtmlTocPage(
                html: responseBody,
                rule: ruleToc,
                listRule: chapterListRule,
                bookUrl: book.bookUrl,
                baseUrl: targetUrlStr)
        }
    }

    private func parseHtmlTocPage(
        html: String,
        rule: RuleToc,
        listRule: String,
        bookUrl: String,
        baseUrl: String) -> ([Chapter], String?) {
        guard let doc = try? SwiftSoup.parse(html, baseUrl) else {
            return ([], nil)
        }
        let elements = CSSSelectorParser.selectElements(element: doc, rule: listRule)
        if elements.isEmpty() {
            return ([], nil)
        }

        var list: [Chapter] = []
        for element in elements {
            let nameRule = rule.chapterName ?? "text"
            let urlRule = rule.chapterUrl ?? "@href"

            let title = CSSSelectorParser.parseSingle(element: element, rule: nameRule, baseUrl: baseUrl) ?? ""
            let url = CSSSelectorParser.parseSingle(element: element, rule: urlRule, baseUrl: baseUrl) ?? ""

            guard !title.isEmpty, !url.isEmpty else { continue }
            let fullUrl = resolveUrl(url, baseUrl: baseUrl)

            list.append(Chapter(
                url: fullUrl,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                bookUrl: bookUrl,
                index: 0))
        }

        var nextUrl: String?
        if let nextRule = rule.nextTocUrl, !nextRule.isEmpty,
           let val = CSSSelectorParser.parseSingle(element: doc, rule: nextRule, baseUrl: baseUrl), !val.isEmpty {
            nextUrl = resolveUrl(val, baseUrl: baseUrl)
        }

        return (list, nextUrl)
    }

    private struct TocContext {
        let baseUrl: String
        let source: BookSource
        let book: Book
    }

    private func parseJsonTocPage(
        json: String,
        rule: RuleToc,
        listRule: String,
        context: TocContext) -> [Chapter] {
        var targetArray: [Any]? = JSONPathParser.parseArray(json: json, path: listRule)

        if targetArray == nil || targetArray?.isEmpty == true, listRule.contains("<js>") || listRule.contains("@js:") {
            let jsEngine = JSEngine()
            let cleanScript = listRule
                .replacingOccurrences(of: "<js>", with: "")
                .replacingOccurrences(of: "</js>", with: "")
                .replacingOccurrences(of: "@js:", with: "")
            let bindings: [String: Any] = [
                "result": json,
                "baseUrl": context.baseUrl,
                "bookUrl": context.book.bookUrl,
                "bookName": context.book.name,
                "bookAuthor": context.book.author,
                "bookSourceUrl": context.source.bookSourceUrl,
                "bookSourceName": context.source.bookSourceName,
                "loginUrl": context.source.loginUrl ?? "",
            ]
            if let jsOutput = jsEngine.evaluate(script: cleanScript, bindings: bindings) {
                targetArray = JSONPathParser.parseArray(json: jsOutput, path: "$")
                    ?? JSONPathParser.parseArray(json: jsOutput, path: "$.*")
            }
        }

        guard let array = targetArray else { return [] }

        var list: [Chapter] = []
        for (index, item) in array.enumerated() {
            guard let dict = item as? [String: Any] else { continue }

            let title = RuleEvaluator.evaluate(dict: dict, rule: rule.chapterName, baseUrl: context.baseUrl) ?? ""
            let url = RuleEvaluator.evaluate(dict: dict, rule: rule.chapterUrl, baseUrl: context.baseUrl) ?? ""

            guard !title.isEmpty, !url.isEmpty else { continue }

            let fullUrl = resolveUrl(url, baseUrl: context.baseUrl)
            list.append(Chapter(
                url: fullUrl,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                bookUrl: context.book.bookUrl,
                index: index))
        }

        return list
    }

    private func resolveUrl(_ url: String, baseUrl: String) -> String {
        AnalyzeUrl.resolveAbsoluteUrl(url, baseUrl: baseUrl)
    }
}
