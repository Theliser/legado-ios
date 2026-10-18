import Foundation
import SwiftSoup

/// 发现流分类解析与书籍拉取引擎
public final class SourceExploreService: Sendable {
    public static let shared = SourceExploreService()

    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 从书源 exploreUrl 配置中解析出分类与榜单项
    public func parseCategories(source: BookSource) -> [ExploreCategory] {
        guard let exploreUrl = source.exploreUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !exploreUrl.isEmpty else {
            return []
        }

        // 1. 尝试 JSON 数组解析 [{"title":"玄幻","url":"/sort/1_{{page}}.html"}]
        if exploreUrl.hasPrefix("["), let data = exploreUrl.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array.compactMap { dict in
                guard let title = (dict["title"] as? String) ?? (dict["name"] as? String),
                      let url = (dict["url"] as? String) ?? (dict["href"] as? String) else {
                    return nil
                }
                let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanTitle.isEmpty, !cleanUrl.isEmpty else {
                    return nil
                }
                return ExploreCategory(
                    sourceUrl: source.bookSourceUrl,
                    sourceName: source.bookSourceName,
                    title: cleanTitle,
                    categoryUrl: cleanUrl)
            }
        }

        // 2. 换行与双冒号分隔格式解析: "玄幻::/sort/1_{{page}}.html\n都市::/sort/2_{{page}}.html"
        let lines = exploreUrl.components(separatedBy: .newlines)
        var results: [ExploreCategory] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "::")
            if parts.count >= 2 {
                let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let url = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty, !url.isEmpty {
                    results.append(ExploreCategory(
                        sourceUrl: source.bookSourceUrl,
                        sourceName: source.bookSourceName,
                        title: title,
                        categoryUrl: url))
                }
            }
        }

        return results
    }

    /// 抓取指定分类和分页的书籍列表
    public func fetchExploreBooks(
        source: BookSource,
        category: ExploreCategory,
        page: Int = 1) async throws -> [Book] {
        let ctx = AnalyzeUrlContext(
            page: page,
            baseUrl: source.bookSourceUrl,
            headerJson: source.header,
            source: source)
        let requestInfo = try AnalyzeUrl(rawUrl: category.categoryUrl, context: ctx)

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

        return parseBooks(
            content: responseBody,
            source: source,
            baseUrl: requestInfo.url.absoluteString)
    }

    /// 解析书籍内容公开接口（供分类流和测试复用）
    public func parseBooks(
        content: String,
        source: BookSource,
        baseUrl: String) -> [Book] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return parseBooks(
            content: content,
            trimmed: trimmed,
            source: source,
            baseUrl: baseUrl)
    }

    private struct ExploreBookRule {
        let bookList: String
        let name: String
        let author: String
        let kind: String?
        let intro: String?
        let coverUrl: String?
        let bookUrl: String
    }

    private func parseBooks(
        content: String,
        trimmed _: String,
        source: BookSource,
        baseUrl: String) -> [Book] {
        // 优先使用 ruleExplore，缺失时回退至 ruleSearch
        let bookListRule = source.ruleExplore?.bookList ?? source.ruleSearch?.bookList ?? ""
        let nameRule = source.ruleExplore?.name ?? source.ruleSearch?.name ?? ""
        let authorRule = source.ruleExplore?.author ?? source.ruleSearch?.author ?? ""
        let kindRule = source.ruleExplore?.kind ?? source.ruleSearch?.kind
        let introRule = source.ruleExplore?.intro ?? source.ruleSearch?.intro
        let coverUrlRule = source.ruleExplore?.coverUrl ?? source.ruleSearch?.coverUrl
        let bookUrlRule = source.ruleExplore?.bookUrl ?? source.ruleSearch?.bookUrl ?? ""

        guard !bookListRule.isEmpty else { return [] }

        let rule = ExploreBookRule(
            bookList: bookListRule,
            name: nameRule,
            author: authorRule,
            kind: kindRule,
            intro: introRule,
            coverUrl: coverUrlRule,
            bookUrl: bookUrlRule)

        let analyzer = AnalyzeRule(source: source, baseUrl: baseUrl)
        analyzer.setContent(content, baseUrl: baseUrl)

        let elements = analyzer.getElements(rule.bookList)
        var books: [Book] = []

        for element in elements {
            let itemAnalyzer = AnalyzeRule(source: source, baseUrl: baseUrl)
            itemAnalyzer.setContent(element, baseUrl: baseUrl)

            let name = itemAnalyzer.getString(rule.name)
            guard !name.isEmpty else { continue }

            let author = itemAnalyzer.getString(rule.author)
            let authorName = author.isEmpty ? "未知作者" : author

            let bookUrl = itemAnalyzer.getString(rule.bookUrl, isUrl: true)
            let finalBookUrl = bookUrl.isEmpty ? baseUrl : bookUrl

            let kindStr = itemAnalyzer.getString(rule.kind)
            let kind = kindStr.isEmpty ? nil : kindStr

            let introStr = itemAnalyzer.getString(rule.intro)
            let intro = introStr.isEmpty ? nil : introStr

            let coverStr = itemAnalyzer.getString(rule.coverUrl, isUrl: true)
            let coverUrl = coverStr.isEmpty ? nil : coverStr

            let book = Book(
                bookUrl: finalBookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                name: name,
                author: authorName,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro)
            books.append(book)
        }

        return books
    }
}
