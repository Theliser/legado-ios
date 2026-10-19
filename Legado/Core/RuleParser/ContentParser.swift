import Foundation
import SwiftSoup

/// 章节正文抓取与规则清洗引擎 (兼容 Legado 3.0 AnalyzeUrl, JS 脚本与复合清洗)
public final class ContentParser: Sendable {
    public static let shared = ContentParser()

    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 抓取并清洗指定章节的正文文本
    public func fetchAndParseContent(
        chapterUrl: String,
        source: BookSource,
        baseUrl: String) async throws -> String {
        var fullContent = ""
        var currentUrlStr = chapterUrl
        var visited = Set<String>()
        var page = 0
        let maxPages = 10

        while page < maxPages && !visited.contains(currentUrlStr) {
            visited.insert(currentUrlStr)
            page += 1

            let requestInfo = try AnalyzeUrl(
                rawUrl: currentUrlStr,
                baseUrl: baseUrl.isEmpty ? source.bookSourceUrl : baseUrl,
                headerJson: source.header,
                source: source)

            let responseBody = try await httpClient.fetch(analyzeUrl: requestInfo)

            let trimmed = responseBody.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let ruleContent = source.ruleContent else {
                fullContent += cleanRawHtml(responseBody)
                break
            }

            let (pageText, nextUrlStr) = parsePageContent(
                body: responseBody,
                trimmed: trimmed,
                rule: ruleContent,
                baseUrl: requestInfo.url.absoluteString,
                source: source)

            fullContent += pageText

            if let nextUrlStr,
               !nextUrlStr.isEmpty,
               !visited.contains(nextUrlStr) {
                currentUrlStr = nextUrlStr
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
        trimmed _: String,
        rule: RuleContent,
        baseUrl: String,
        source: BookSource) -> (String, String?) {
        guard let contentRule = rule.content, !contentRule.isEmpty else {
            return (cleanRawHtml(body), nil)
        }

        let analyzer = AnalyzeRule(source: source, baseUrl: baseUrl)
        analyzer.setContent(body, baseUrl: baseUrl)

        var pageText = analyzer.getString(contentRule)
        if pageText.contains("<") {
            pageText = cleanRawHtml(pageText)
        }

        var nextUrl: String?
        if let nextRule = rule.nextContentUrl, !nextRule.isEmpty {
            let next = analyzer.getString(nextRule, isUrl: true)
            if !next.isEmpty {
                nextUrl = next
            }
        }

        return (pageText, nextUrl)
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

    public func cleanContent(_ html: String) -> String {
        formatParagraphs(cleanRawHtml(html))
    }
}
