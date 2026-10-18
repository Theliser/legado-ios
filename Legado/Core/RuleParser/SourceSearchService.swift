import Foundation
import SwiftSoup

/// 单个书源搜索执行服务
public final class SourceSearchService: Sendable {
    public static let shared = SourceSearchService()

    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 执行单个书源搜索
    public func search(
        source: BookSource,
        keyword: String,
        page: Int = 1) async throws -> [SearchResult] {
        guard let rawSearchUrl = source.searchUrl, !rawSearchUrl.isEmpty else {
            return []
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. 构建搜索请求
        let requestInfo = try AnalyzeUrl(
            rawUrl: rawSearchUrl,
            key: keyword,
            page: page,
            baseUrl: source.bookSourceUrl,
            headerJson: source.header,
            source: source)

        // 2. 发起网络抓取
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

        let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        // 3. 解析搜索列表
        guard let ruleSearch = source.ruleSearch,
              let bookListRule = ruleSearch.bookList,
              !bookListRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let trimmedBody = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBody.starts(with: "{") || trimmedBody.starts(with: "[") {
            // JSON 规则提取
            return parseJsonSearch(
                body: trimmedBody,
                ruleSearch: ruleSearch,
                source: source,
                responseTimeMs: elapsedMs)
        } else {
            // HTML / SwiftSoup 规则提取
            return parseHtmlSearch(
                html: responseBody,
                ruleSearch: ruleSearch,
                source: source,
                baseUrl: requestInfo.url.absoluteString,
                responseTimeMs: elapsedMs)
        }
    }

    // MARK: - HTML 解析

    private func parseHtmlSearch(
        html: String,
        ruleSearch: RuleSearch,
        source: BookSource,
        baseUrl: String,
        responseTimeMs: Int) -> [SearchResult] {
        guard let listRule = ruleSearch.bookList,
              let doc = try? SwiftSoup.parse(html, baseUrl) else {
            return []
        }

        let elements = CSSSelectorParser.selectElements(element: doc, rule: listRule)

        var results: [SearchResult] = []

        for element in elements {
            let name = parseElementRule(element, rule: ruleSearch.name, baseUrl: baseUrl) ?? ""
            guard !name.isEmpty else { continue }

            let bookUrl = parseElementRule(element, rule: ruleSearch.bookUrl, baseUrl: baseUrl) ?? ""
            guard !bookUrl.isEmpty else { continue }

            let author = parseElementRule(element, rule: ruleSearch.author, baseUrl: baseUrl) ?? ""
            let kind = parseElementRule(element, rule: ruleSearch.kind, baseUrl: baseUrl)
            let coverUrl = parseElementRule(element, rule: ruleSearch.coverUrl, baseUrl: baseUrl)
            let intro = parseElementRule(element, rule: ruleSearch.intro, baseUrl: baseUrl)
            let latestChapter = parseElementRule(element, rule: ruleSearch.lastChapter, baseUrl: baseUrl)
            let wordCount = parseElementRule(element, rule: ruleSearch.wordCount, baseUrl: baseUrl)

            let fullBookUrl = resolveUrl(bookUrl, baseUrl: baseUrl)
            let fullCoverUrl = coverUrl.map { resolveUrl($0, baseUrl: baseUrl) }

            results.append(SearchResult(
                bookUrl: fullBookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                originOrder: source.customOrder ?? 0,
                name: name,
                author: author,
                kind: kind,
                coverUrl: fullCoverUrl,
                intro: intro,
                latestChapterTitle: latestChapter,
                wordCount: wordCount,
                responseTimeMs: responseTimeMs))
        }

        return results
    }

    private func parseElementRule(_ element: Element, rule: String?, baseUrl: String) -> String? {
        guard let rule, !rule.isEmpty else { return nil }
        return CSSSelectorParser.parseSingle(element: element, rule: rule, baseUrl: baseUrl)
    }

    // MARK: - JSON 解析

    private func parseJsonSearch(
        body: String,
        ruleSearch: RuleSearch,
        source: BookSource,
        responseTimeMs: Int) -> [SearchResult] {
        guard let listRule = ruleSearch.bookList,
              let array = JSONPathParser.parseArray(json: body, path: listRule) else {
            return []
        }

        let baseUrl = source.bookSourceUrl
        var results: [SearchResult] = []
        for item in array {
            guard let dict = item as? [String: Any] else { continue }
            let eval: (String?) -> String? = { ruleStr in
                RuleEvaluator.evaluate(dict: dict, rule: ruleStr, baseUrl: baseUrl)
            }

            let name = eval(ruleSearch.name) ?? ""
            let bookUrl = eval(ruleSearch.bookUrl) ?? ""
            guard !name.isEmpty, !bookUrl.isEmpty else { continue }

            let author = eval(ruleSearch.author) ?? ""
            let kind = eval(ruleSearch.kind)
            let coverUrl = eval(ruleSearch.coverUrl)
            let intro = eval(ruleSearch.intro)
            let lastChapter = eval(ruleSearch.lastChapter)
            let wordCount = eval(ruleSearch.wordCount)

            let fullBookUrl = resolveUrl(bookUrl, baseUrl: baseUrl)
            let fullCoverUrl = coverUrl.map { resolveUrl($0, baseUrl: baseUrl) }

            results.append(SearchResult(
                bookUrl: fullBookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                originOrder: source.customOrder ?? 0,
                name: name,
                author: author,
                kind: kind,
                coverUrl: fullCoverUrl,
                intro: intro,
                latestChapterTitle: lastChapter,
                wordCount: wordCount,
                responseTimeMs: responseTimeMs))
        }

        return results
    }

    // MARK: - URL 辅助

    private func resolveUrl(_ url: String, baseUrl: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }
        guard let base = URL(string: baseUrl),
              let resolved = URL(string: trimmed, relativeTo: base) else {
            return trimmed
        }
        return resolved.absoluteURL.absoluteString
    }
}
