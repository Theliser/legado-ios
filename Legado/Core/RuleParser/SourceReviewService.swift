import Foundation

/// 章节段评与书源评语解析服务 (对齐 Android Legado `ReviewRule` & `BookChapterReview`)
public final class SourceReviewService: Sendable {
    private let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    /// 根据书源 reviewRule 解析章节评语 / 段落评论
    public func fetchChapterReviews(
        book: Book,
        chapter: Chapter,
        source: BookSource) async throws -> BookChapterReview {
        guard let ruleReview = source.ruleReview,
              let reviewUrlRule = ruleReview.reviewUrl,
              !reviewUrlRule.isEmpty else {
            return BookChapterReview(
                bookId: book.id,
                chapterId: chapter.id,
                summaryUrl: "",
                reviewCount: 0,
                reviews: [])
        }

        let analyzeUrl = try AnalyzeUrl(
            rawUrl: reviewUrlRule,
            key: book.name,
            page: 1,
            baseUrl: source.bookSourceUrl,
            headerJson: source.header,
            source: source,
            book: book)

        let html = try await fetchHtml(for: analyzeUrl)
        let analyzer = AnalyzeRule(
            book: book,
            source: source,
            chapter: chapter,
            baseUrl: analyzeUrl.url.absoluteString)
        analyzer.setContent(html, baseUrl: analyzeUrl.url.absoluteString)

        let reviewItems = parseReviewItems(
            from: analyzer,
            ruleReview: ruleReview,
            source: source,
            baseUrl: analyzeUrl.url.absoluteString)

        return BookChapterReview(
            bookId: book.id,
            chapterId: chapter.id,
            summaryUrl: analyzeUrl.url.absoluteString,
            reviewCount: reviewItems.count,
            reviews: reviewItems)
    }

    private func fetchHtml(for analyzeUrl: AnalyzeUrl) async throws -> String {
        if let client = httpClient as? HTTPClient {
            return try await client.fetch(analyzeUrl: analyzeUrl)
        } else if analyzeUrl.method == "POST" {
            return try await httpClient.post(
                url: analyzeUrl.url,
                body: analyzeUrl.body,
                headers: analyzeUrl.headers,
                timeout: 15)
        } else {
            return try await httpClient.get(
                url: analyzeUrl.url,
                headers: analyzeUrl.headers,
                timeout: 15)
        }
    }

    private func parseReviewItems(
        from analyzer: AnalyzeRule,
        ruleReview: RuleReview,
        source: BookSource,
        baseUrl: String) -> [BookReviewItem] {
        guard let contentRule = ruleReview.contentRule, !contentRule.isEmpty else { return [] }
        var reviewItems: [BookReviewItem] = []

        let elements = analyzer.getElements(contentRule)
        if !elements.isEmpty {
            for element in elements {
                let itemAnalyzer = AnalyzeRule(source: source)
                itemAnalyzer.setContent(element, baseUrl: baseUrl)

                let content = itemAnalyzer.getString(ruleReview.contentRule ?? "")
                let author = ruleReview.avatarRule != nil ? itemAnalyzer.getString(ruleReview.avatarRule ?? "") : ""
                let postTime = ruleReview.postTimeRule != nil ?
                    itemAnalyzer.getString(ruleReview.postTimeRule ?? "") : nil
                let avatar = ruleReview.avatarRule != nil ? itemAnalyzer.getString(ruleReview.avatarRule ?? "") : nil

                if !content.isEmpty {
                    reviewItems.append(BookReviewItem(
                        author: author.isEmpty ? "书友" : author,
                        avatar: avatar,
                        content: content,
                        postTime: postTime,
                        voteUp: 0,
                        voteDown: 0))
                }
            }
        } else if let stringList = analyzer.getStringList(contentRule) {
            for str in stringList where !str.isEmpty {
                reviewItems.append(BookReviewItem(author: "书友", content: str))
            }
        }
        return reviewItems
    }
}
