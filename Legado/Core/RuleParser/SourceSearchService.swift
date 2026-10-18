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

        let baseUrl = requestInfo.url.absoluteString
        let analyzer = AnalyzeRule(source: source, baseUrl: baseUrl)
        analyzer.setContent(responseBody, baseUrl: baseUrl)

        let elements = analyzer.getElements(bookListRule)
        return elements.compactMap { element in
            mapSearchResult(
                element: element,
                ruleSearch: ruleSearch,
                source: source,
                baseUrl: baseUrl,
                elapsedMs: elapsedMs)
        }
    }

    private func mapSearchResult(
        element: Any,
        ruleSearch: RuleSearch,
        source: BookSource,
        baseUrl: String,
        elapsedMs: Int) -> SearchResult? {
        let itemAnalyzer = AnalyzeRule(source: source, baseUrl: baseUrl)
        itemAnalyzer.setContent(element, baseUrl: baseUrl)

        let name = itemAnalyzer.getString(ruleSearch.name)
        guard !name.isEmpty else { return nil }

        let bookUrl = itemAnalyzer.getString(ruleSearch.bookUrl, isUrl: true)
        guard !bookUrl.isEmpty else { return nil }

        let author = itemAnalyzer.getString(ruleSearch.author)
        let kindStr = itemAnalyzer.getString(ruleSearch.kind)
        let coverStr = itemAnalyzer.getString(ruleSearch.coverUrl, isUrl: true)
        let introStr = itemAnalyzer.getString(ruleSearch.intro)
        let lastChapterStr = itemAnalyzer.getString(ruleSearch.lastChapter)
        let wordCountStr = itemAnalyzer.getString(ruleSearch.wordCount)

        return SearchResult(
            bookUrl: bookUrl,
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            originOrder: source.customOrder ?? 0,
            name: name,
            author: author,
            kind: kindStr.isEmpty ? nil : kindStr,
            coverUrl: coverStr.isEmpty ? nil : coverStr,
            intro: introStr.isEmpty ? nil : introStr,
            latestChapterTitle: lastChapterStr.isEmpty ? nil : lastChapterStr,
            wordCount: wordCountStr.isEmpty ? nil : wordCountStr,
            responseTimeMs: elapsedMs)
    }
}
