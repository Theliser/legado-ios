import Foundation
import SwiftSoup

/// 单个书源搜索执行服务
public final class SourceSearchService: Sendable {
    public static let shared = SourceSearchService()

    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 执行单个书源搜索 (全面通过 WebBook 统一中枢执行)
    public func search(
        source: BookSource,
        keyword: String,
        page: Int = 1) async throws -> [SearchResult] {
        guard let rawSearchUrl = source.searchUrl, !rawSearchUrl.isEmpty else {
            return []
        }
        return try await WebBook.searchBookAwait(
            bookSource: source,
            key: keyword,
            page: page,
            httpClient: httpClient)
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
