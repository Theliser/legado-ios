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
                return ExploreCategory(
                    sourceUrl: source.bookSourceUrl,
                    sourceName: source.bookSourceName,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    categoryUrl: url.trimmingCharacters(in: .whitespacesAndNewlines))
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
        // 宏替换当前页码
        let resolvedPath = category.categoryUrl
            .replacingOccurrences(of: "{{page}}", with: "\(page)")
            .replacingOccurrences(of: "<page>", with: "\(page)")

        // 解析完整 URL
        guard let base = URL(string: source.bookSourceUrl),
              let targetUrl = URL(string: resolvedPath, relativeTo: base)?.absoluteURL else {
            throw URLError(.badURL)
        }

        var headers: [String: String]?
        if let headerJson = source.header,
           let data = headerJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            headers = parsed
        }

        let responseBody = try await httpClient.get(url: targetUrl, headers: headers)
        return parseBooks(
            content: responseBody,
            source: source,
            baseUrl: targetUrl.absoluteString)
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
        trimmed: String,
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

        // JSON 响应解析
        if trimmed.starts(with: "{") || trimmed.starts(with: "[") {
            return parseJsonBooks(
                json: trimmed,
                source: source,
                rule: rule,
                baseUrl: baseUrl)
        }

        // HTML 响应解析
        return parseHtmlBooks(
            html: content,
            source: source,
            rule: rule,
            baseUrl: baseUrl)
    }

    private func parseHtmlBooks(
        html: String,
        source: BookSource,
        rule: ExploreBookRule,
        baseUrl: String) -> [Book] {
        guard let doc = try? SwiftSoup.parse(html, baseUrl) else {
            return []
        }

        let elements: Elements
        do {
            elements = try doc.select(rule.bookList)
        } catch {
            return []
        }

        var books: [Book] = []
        for element in elements.array() {
            guard let name = CSSSelectorParser.parseSingle(element: element, rule: rule.name, baseUrl: baseUrl),
                  !name.isEmpty else {
                continue
            }

            let author = CSSSelectorParser.parseSingle(
                element: element,
                rule: rule.author,
                baseUrl: baseUrl) ?? "未知作者"
            let bookUrl = CSSSelectorParser.parseSingle(
                element: element,
                rule: rule.bookUrl,
                baseUrl: baseUrl) ?? baseUrl
            let kind = rule.kind.flatMap {
                CSSSelectorParser.parseSingle(element: element, rule: $0, baseUrl: baseUrl)
            }
            let intro = rule.intro.flatMap {
                CSSSelectorParser.parseSingle(element: element, rule: $0, baseUrl: baseUrl)
            }
            let coverUrl = rule.coverUrl.flatMap {
                CSSSelectorParser.parseSingle(element: element, rule: $0, baseUrl: baseUrl)
            }

            let book = Book(
                bookUrl: bookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                name: name,
                author: author,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro)
            books.append(book)
        }

        return books
    }

    private func parseJsonBooks(
        json: String,
        source: BookSource,
        rule: ExploreBookRule,
        baseUrl: String) -> [Book] {
        let items = JSONPathParser.parse(json: json, path: rule.bookList)
        var books: [Book] = []

        for itemJson in items {
            guard let name = JSONPathParser.parse(json: itemJson, path: rule.name).first,
                  !name.isEmpty else {
                continue
            }

            let author = JSONPathParser.parse(json: itemJson, path: rule.author).first ?? "未知作者"
            let rawUrl = JSONPathParser.parse(json: itemJson, path: rule.bookUrl).first ?? ""
            let bookUrl = URL(string: rawUrl, relativeTo: URL(string: baseUrl))?.absoluteString ?? rawUrl

            let kind = rule.kind.flatMap { JSONPathParser.parse(json: itemJson, path: $0).first }
            let intro = rule.intro.flatMap { JSONPathParser.parse(json: itemJson, path: $0).first }
            let rawCover = rule.coverUrl.flatMap { JSONPathParser.parse(json: itemJson, path: $0).first }
            let coverUrl = rawCover.flatMap { URL(string: $0, relativeTo: URL(string: baseUrl))?.absoluteString }

            let book = Book(
                bookUrl: bookUrl,
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                name: name,
                author: author,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro)
            books.append(book)
        }

        return books
    }
}
