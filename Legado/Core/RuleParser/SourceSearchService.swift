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
        let requestInfo = try buildSearchRequest(
            rawSearchUrl: rawSearchUrl,
            baseUrl: source.bookSourceUrl,
            keyword: keyword,
            page: page,
            headerJson: source.header)

        // 2. 发起网络抓取
        let responseBody: String
        if requestInfo.method.uppercased() == "POST" {
            let bodyData = requestInfo.body?.data(using: .utf8)
            responseBody = try await httpClient.post(
                url: requestInfo.url,
                body: bodyData,
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

        let elements: Elements
        do {
            elements = try doc.select(listRule)
        } catch {
            return []
        }

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

        var results: [SearchResult] = []
        for item in array {
            guard let dict = item as? [String: Any] else { continue }

            let name = parseJsonField(dict, rule: ruleSearch.name) ?? ""
            let bookUrl = parseJsonField(dict, rule: ruleSearch.bookUrl) ?? ""
            guard !name.isEmpty, !bookUrl.isEmpty else { continue }

            let author = parseJsonField(dict, rule: ruleSearch.author) ?? ""
            let kind = parseJsonField(dict, rule: ruleSearch.kind)
            let coverUrl = parseJsonField(dict, rule: ruleSearch.coverUrl)
            let intro = parseJsonField(dict, rule: ruleSearch.intro)
            let lastChapter = parseJsonField(dict, rule: ruleSearch.lastChapter)
            let wordCount = parseJsonField(dict, rule: ruleSearch.wordCount)

            let fullBookUrl = resolveUrl(bookUrl, baseUrl: source.bookSourceUrl)
            let fullCoverUrl = coverUrl.map { resolveUrl($0, baseUrl: source.bookSourceUrl) }

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

    private func parseJsonField(_ dict: [String: Any], rule: String?) -> String? {
        guard let rule, !rule.isEmpty else { return nil }
        let trimmed = rule.replacingOccurrences(of: "$.", with: "").trimmingCharacters(in: .whitespaces)
        if let val = dict[trimmed] {
            return "\(val)"
        }
        return nil
    }

    // MARK: - URL 构建

    private struct RequestInfo {
        let url: URL
        let method: String
        let body: String?
        let headers: [String: String]
    }

    private func buildSearchRequest(
        rawSearchUrl: String,
        baseUrl: String,
        keyword: String,
        page: Int,
        headerJson: String?) throws -> RequestInfo {
        var method = "GET"
        var bodyString: String?
        var urlPart = rawSearchUrl
        var customHeaders: [String: String] = [:]

        // 解析头部配置
        if let headerJson, !headerJson.isEmpty,
           let data = headerJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            customHeaders = parsed
        }

        // 解析 Legado searchUrl 复合配置: url,{"method": "POST", "body": "key={{key}}"}
        if let commaIndex = rawSearchUrl.firstIndex(of: ",") {
            let potentialJson = String(rawSearchUrl[rawSearchUrl.index(after: commaIndex)...])
            if potentialJson.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                urlPart = String(rawSearchUrl[..<commaIndex])
                if let data = potentialJson.data(using: .utf8),
                   let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let optMethod = options["method"] as? String {
                        method = optMethod
                    }
                    if let optBody = options["body"] as? String {
                        bodyString = optBody
                    }
                    if let optHeaders = options["headers"] as? [String: String] {
                        customHeaders.merge(optHeaders) { _, new in new }
                    }
                }
            }
        }

        // 替换占位符 {{key}}, {{page}}, searchKey
        let encodedKey = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let resolvedUrlString = urlPart
            .replacingOccurrences(of: "{{key}}", with: encodedKey)
            .replacingOccurrences(of: "{{searchKey}}", with: encodedKey)
            .replacingOccurrences(of: "{{page}}", with: "\(page)")

        if let body = bodyString {
            bodyString = body
                .replacingOccurrences(of: "{{key}}", with: keyword)
                .replacingOccurrences(of: "{{searchKey}}", with: keyword)
                .replacingOccurrences(of: "{{page}}", with: "\(page)")
        }

        let fullUrlString = resolveUrl(resolvedUrlString, baseUrl: baseUrl)
        guard let url = URL(string: fullUrlString) else {
            throw URLError(.badURL)
        }

        return RequestInfo(
            url: url,
            method: method,
            body: bodyString,
            headers: customHeaders)
    }

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
