import Foundation
import SwiftSoup

/// 章节正文抓取与规则清洗引擎
public final class ContentParser: Sendable {
    public static let shared = ContentParser()

    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = .shared) {
        self.httpClient = httpClient
    }

    /// 抓取并清洗指定章节的正文文本
    public func fetchAndParseContent(
        chapterUrl: String,
        source: BookSource,
        baseUrl _: String) async throws -> String {
        guard let url = URL(string: chapterUrl) else {
            throw URLError(.badURL)
        }

        var headers: [String: String]?
        if let headerJson = source.header,
           let data = headerJson.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            headers = parsed
        }

        var fullContent = ""
        var currentUrl = url
        var visited = Set<String>()
        var page = 0
        let maxPages = 10

        while page < maxPages && !visited.contains(currentUrl.absoluteString) {
            visited.insert(currentUrl.absoluteString)
            page += 1

            let responseBody = try await httpClient.get(url: currentUrl, headers: headers)
            let trimmed = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let ruleContent = source.ruleContent else {
                fullContent += cleanRawHtml(responseBody)
                break
            }

            let (pageText, nextUrlStr) = parsePageContent(
                body: responseBody,
                trimmed: trimmed,
                rule: ruleContent,
                baseUrl: currentUrl.absoluteString)

            fullContent += pageText

            if let nextUrlStr,
               !nextUrlStr.isEmpty,
               let next = URL(string: nextUrlStr, relativeTo: currentUrl)?.absoluteURL,
               !visited.contains(next.absoluteString) {
                currentUrl = next
            } else {
                break
            }
        }

        // 应用书源正文替换正则净化 (例如 ##广告.*##)
        if let sourceRegex = source.ruleContent?.sourceRegex, !sourceRegex.isEmpty {
            fullContent = RuleAnalyzer.applyRegexReplace(text: fullContent, regexRule: sourceRegex)
        }

        return formatParagraphs(fullContent)
    }

    private func parsePageContent(
        body: String,
        trimmed: String,
        rule: RuleContent,
        baseUrl: String) -> (String, String?) {
        let isJson = trimmed.starts(with: "{") || trimmed.starts(with: "[")
        if isJson {
            var text = ""
            if let contentRule = rule.content {
                text = JSONPathParser.parse(json: trimmed, path: contentRule).joined(separator: "\n")
            }
            var nextUrl: String?
            if let nextRule = rule.nextContentUrl {
                nextUrl = JSONPathParser.parse(json: trimmed, path: nextRule).first
            }
            return (text, nextUrl)
        } else {
            return parseHtmlContent(html: body, rule: rule, baseUrl: baseUrl)
        }
    }

    private func parseHtmlContent(html: String, rule: RuleContent, baseUrl: String) -> (String, String?) {
        guard let doc = try? SwiftSoup.parse(html, baseUrl) else {
            return (cleanRawHtml(html), nil)
        }

        // 移除无关的 script 和 style 元素
        _ = try? doc.select("script, style, noscript, header, footer").remove()

        var rawContent = ""
        if let contentRule = rule.content, !contentRule.isEmpty {
            // 如果规则指定了 CSS 选择器
            if let element = try? doc.select(contentRule).first() {
                // 将 <p> 和 <br> 转换为换行符
                let htmlStr = (try? element.html()) ?? (try? element.text()) ?? ""
                rawContent = cleanRawHtml(htmlStr)
            } else {
                let texts = CSSSelectorParser.parse(element: doc, rule: contentRule, baseUrl: baseUrl)
                rawContent = texts.joined(separator: "\n")
            }
        } else {
            rawContent = cleanRawHtml(html)
        }

        var nextUrl: String?
        if let nextRule = rule.nextContentUrl, !nextRule.isEmpty {
            nextUrl = CSSSelectorParser.parseSingle(element: doc, rule: nextRule, baseUrl: baseUrl)
        }

        return (rawContent, nextUrl)
    }

    /// 清洗 HTML 标签并将文本段落规范化
    public func cleanRawHtml(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: "(?is)<script[\\s\\S]*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<style[\\s\\S]*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n")
            .replacingOccurrences(of: "<p.*?>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<div.*?>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "</div>", with: "\n")
            .replacingOccurrences(of: "<.*?>", with: "", options: .regularExpression)

        // HTML 实体替换
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&ldquo;", with: "“")
            .replacingOccurrences(of: "&rdquo;", with: "”")
            .replacingOccurrences(of: "&lsquo;", with: "‘")
            .replacingOccurrences(of: "&rsquo;", with: "’")

        return text
    }

    /// 中文自然段落排版：过滤空行，首行缩进两个全角空格 (\u3000\u3000)
    public func formatParagraphs(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var formattedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "^\u{3000}+", with: "", options: .regularExpression)
            guard !trimmed.isEmpty else { continue }

            formattedLines.append("\u{3000}\u{3000}" + trimmed)
        }

        return formattedLines.joined(separator: "\n\n")
    }

    /// 一键清洗并完成段落排版
    public func cleanContent(_ html: String) -> String {
        formatParagraphs(cleanRawHtml(html))
    }
}
