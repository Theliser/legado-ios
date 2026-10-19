import Foundation
import SwiftSoup

/// 章节正文抓取与规则清洗引擎 (兼容 Legado 3.0 AnalyzeUrl, JS 脚本与复合清洗)
public final class ContentParser: Sendable {
    public static let shared = ContentParser()

    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 抓取并清洗指定章节的正文文本 (全面通过 WebBook 统一中枢执行，支持多页与正则替换)
    public func fetchAndParseContent(
        chapterUrl: String,
        source: BookSource,
        baseUrl: String) async throws -> String {
        let dummyBook = Book(
            bookUrl: baseUrl.isEmpty ? source.bookSourceUrl : baseUrl,
            origin: source.bookSourceUrl,
            originName: source.bookSourceName,
            name: "",
            author: "")
        var chapter = Chapter(
            url: chapterUrl,
            title: "",
            bookUrl: dummyBook.bookUrl,
            index: 0,
            baseUrl: baseUrl.isEmpty ? source.bookSourceUrl : baseUrl)
        return try await WebBook.getContentAwait(
            bookSource: source,
            book: dummyBook,
            bookChapter: &chapter,
            httpClient: httpClient)
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

    public static func clean(_ html: String) -> String {
        shared.cleanContent(html)
    }
}
