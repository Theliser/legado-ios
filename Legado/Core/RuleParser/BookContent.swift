import Foundation

/// 章节正文解析引擎 (对齐 Android Legado io.legado.app.model.webBook.BookContent.kt)
public enum BookContent {
    private static let maxNextPageConcurrency = 4
    private static let imgRegex = try? NSRegularExpression(
        pattern: #"\(?(.*?)\)?(https?://\S+\.(?:jpg|png|jpeg|webp|gif))"#,
        options: .caseInsensitive)

    public struct RequestContext: Sendable {
        public let baseUrl: String
        public let redirectUrl: String
        public let nextChapterUrl: String?
        public let needSave: Bool

        public init(
            baseUrl: String,
            redirectUrl: String,
            nextChapterUrl: String? = nil,
            needSave: Bool = true) {
            self.baseUrl = baseUrl
            self.redirectUrl = redirectUrl
            self.nextChapterUrl = nextChapterUrl
            self.needSave = needSave
        }
    }

    private struct SourceContext: Sendable {
        let bookSource: BookSource
        let book: Book
        let chapter: Chapter
        let contentRule: ContentRule
    }

    private struct PageArgs: Sendable {
        let context: SourceContext
        let pageUrl: String
        let redirectUrl: String
        let body: String
        let nextChapterUrl: String?
    }

    // swiftlint:disable function_parameter_count
    /// 提取并格式化章节正文 (便捷入口)
    public static func analyzeContent(
        bookSource: BookSource,
        book: Book,
        chapter: Chapter,
        baseUrl: String,
        redirectUrl: String,
        body: String?,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> String {
        var mutableChapter = chapter
        let context = RequestContext(baseUrl: baseUrl, redirectUrl: redirectUrl)
        return try await analyzeContent(
            bookSource: bookSource,
            book: book,
            bookChapter: &mutableChapter,
            body: body,
            context: context,
            httpClient: httpClient)
    }

    // swiftlint:enable function_parameter_count

    /// 提取并格式化章节正文 (结构化参数入口)
    public static func analyzeContent(
        bookSource: BookSource,
        book: Book,
        bookChapter: inout Chapter,
        body: String?,
        context: RequestContext,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> String {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "BookContent",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "获取正文失败: \(context.baseUrl)"])
        }

        var sourceMutable = bookSource
        let contentRule = sourceMutable.getContentRule()
        let sCtx = SourceContext(
            bookSource: bookSource,
            book: book,
            chapter: bookChapter,
            contentRule: contentRule)

        let analyzeRule = AnalyzeRule(book: book, source: bookSource, baseUrl: context.baseUrl)
        analyzeRule.setContent(body, baseUrl: context.baseUrl)
        _ = analyzeRule.setRedirectUrl(context.redirectUrl)
        analyzeRule.setChapter(bookChapter)
        analyzeRule.setNextChapterUrl(context.nextChapterUrl)

        var contentBuilder: [String] = []
        let pArgs = PageArgs(
            context: sCtx,
            pageUrl: context.baseUrl,
            redirectUrl: context.redirectUrl,
            body: body,
            nextChapterUrl: context.nextChapterUrl)
        let (firstPage, nextUrls) = try analyzeSinglePage(args: pArgs, getNextPageUrl: true)
        if !firstPage.isEmpty {
            contentBuilder.append(firstPage)
        }

        try await processNextPages(
            nextUrls: nextUrls,
            context: context,
            sCtx: sCtx,
            contentBuilder: &contentBuilder,
            httpClient: httpClient)

        try await handleSubContent(
            sCtx: sCtx,
            analyzeRule: analyzeRule,
            redirectUrl: context.redirectUrl,
            contentBuilder: &contentBuilder,
            httpClient: httpClient)

        var contentStr = contentBuilder.joined(separator: "\n")
        applyTitleRule(contentRule: contentRule, analyzeRule: analyzeRule, bookChapter: &bookChapter)
        contentStr = applyReplaceRegex(contentRule: contentRule, analyzeRule: analyzeRule, contentStr: contentStr)

        if !bookChapter.isVolume && contentStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(domain: "BookContent", code: -2, userInfo: [NSLocalizedDescriptionKey: "正文内容为空"])
        }

        return contentStr
    }

    private static func processNextPages(
        nextUrls: [String],
        context: RequestContext,
        sCtx: SourceContext,
        contentBuilder: inout [String],
        httpClient: HTTPClientProtocol) async throws {
        if nextUrls.count == 1 {
            try await fetchSequentialPages(
                firstNextUrl: nextUrls[0],
                context: context,
                sCtx: sCtx,
                contentBuilder: &contentBuilder,
                httpClient: httpClient)
        } else if nextUrls.count > 1 {
            try await fetchParallelPages(
                nextUrls: nextUrls,
                context: context,
                sCtx: sCtx,
                contentBuilder: &contentBuilder,
                httpClient: httpClient)
        }
    }

    private static func fetchSequentialPages(
        firstNextUrl: String,
        context: RequestContext,
        sCtx: SourceContext,
        contentBuilder: inout [String],
        httpClient: HTTPClientProtocol) async throws {
        var nextUrl = firstNextUrl
        var nextUrlList: Set<String> = [context.redirectUrl]

        while !nextUrl.isEmpty, !nextUrlList.contains(nextUrl) {
            if let targetNext = context.nextChapterUrl, !targetNext.isEmpty,
               AnalyzeUrl.resolveAbsoluteUrl(nextUrl, baseUrl: context.redirectUrl) ==
               AnalyzeUrl.resolveAbsoluteUrl(targetNext, baseUrl: context.redirectUrl) {
                break
            }
            nextUrlList.insert(nextUrl)

            let analyzeUrl = try AnalyzeUrl(
                mUrl: nextUrl,
                baseUrl: context.redirectUrl,
                source: sCtx.bookSource,
                chapter: sCtx.chapter,
                book: sCtx.book)
            let res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)
            guard let nextBody = res.body, !nextBody.isEmpty else { break }

            let pArgs = PageArgs(
                context: sCtx,
                pageUrl: nextUrl,
                redirectUrl: res.url,
                body: nextBody,
                nextChapterUrl: context.nextChapterUrl)
            let subData = try analyzeSinglePage(args: pArgs, getNextPageUrl: true)
            nextUrl = subData.1.first ?? ""
            if !subData.0.isEmpty {
                contentBuilder.append(subData.0)
            }
        }
    }

    private static func fetchParallelPages(
        nextUrls: [String],
        context: RequestContext,
        sCtx: SourceContext,
        contentBuilder: inout [String],
        httpClient: HTTPClientProtocol) async throws {
        let parallelUrls = Array(nextUrls.prefix(10))
        let results = try await withThrowingTaskGroup(of: (Int, String).self) { group -> [String] in
            var ordered: [String] = Array(repeating: "", count: parallelUrls.count)
            for (index, pageUrl) in parallelUrls.enumerated() {
                group.addTask {
                    let analyzeUrl = try AnalyzeUrl(
                        mUrl: pageUrl,
                        baseUrl: context.redirectUrl,
                        source: sCtx.bookSource,
                        chapter: sCtx.chapter,
                        book: sCtx.book)
                    let res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)
                    let pArgs = PageArgs(
                        context: sCtx,
                        pageUrl: pageUrl,
                        redirectUrl: res.url,
                        body: res.body ?? "",
                        nextChapterUrl: context.nextChapterUrl)
                    let pageText = try analyzeSinglePage(args: pArgs, getNextPageUrl: false).0
                    return (index, pageText)
                }
            }
            for try await(idx, text) in group {
                ordered[idx] = text
            }
            return ordered
        }
        for text in results where !text.isEmpty {
            contentBuilder.append(text)
        }
    }

    private static func handleSubContent(
        sCtx: SourceContext,
        analyzeRule: AnalyzeRule,
        redirectUrl: String,
        contentBuilder: inout [String],
        httpClient: HTTPClientProtocol) async throws {
        guard let subRule = sCtx.contentRule.subContent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !subRule.isEmpty else { return }

        let rawSub = analyzeRule.getString(subRule).trimmingCharacters(in: .whitespacesAndNewlines)
        let subContent: String
        if rawSub.lowercased().hasPrefix("http") {
            let analyzeUrl = try AnalyzeUrl(
                mUrl: rawSub,
                baseUrl: redirectUrl,
                source: sCtx.bookSource,
                chapter: sCtx.chapter,
                book: sCtx.book)
            subContent = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient).body ?? ""
        } else {
            subContent = rawSub
        }

        if !subContent.isEmpty, sCtx.book.isOnLineTxt {
            contentBuilder.append(subContent)
        }
    }

    private static func applyTitleRule(
        contentRule: ContentRule,
        analyzeRule: AnalyzeRule,
        bookChapter: inout Chapter) {
        guard let titleRule = contentRule.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !titleRule.isEmpty else { return }
        var title = analyzeRule.getString(titleRule).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        if let regex = imgRegex,
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
            if let range1 = Range(match.range(at: 1), in: title) {
                let group1 = String(title[range1]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !group1.isEmpty {
                    title = group1
                }
            }
            if let range2 = Range(match.range(at: 2), in: title) {
                bookChapter.reviewImg = String(title[range2])
            }
        }
        bookChapter.title = title
        bookChapter.titleMD5 = nil
    }

    private static func applyReplaceRegex(
        contentRule: ContentRule,
        analyzeRule _: AnalyzeRule,
        contentStr: String) -> String {
        var result = contentStr
        if let sourceRegex = contentRule.sourceRegex?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceRegex.isEmpty {
            result = RuleAnalyzer.applyRegexReplace(text: result, regexRule: sourceRegex)
        }
        if let replaceRegex = contentRule.replaceRegex?.trimmingCharacters(in: .whitespacesAndNewlines),
           !replaceRegex.isEmpty {
            let cleanedLines = result.components(separatedBy: .newlines).map {
                $0.trimmingCharacters(in: .whitespaces)
            }.joined(separator: "\n")
            result = RuleAnalyzer.applyRegexReplace(text: cleanedLines, regexRule: replaceRegex)
        }
        return result.components(separatedBy: .newlines).map {
            $0.isEmpty ? "" : "　　\($0.trimmingCharacters(in: .whitespaces))"
        }.joined(separator: "\n")
    }

    private static func analyzeSinglePage(
        args: PageArgs,
        getNextPageUrl: Bool) throws -> (String, [String]) {
        let analyzeRule = AnalyzeRule(
            book: args.context.book,
            source: args.context.bookSource,
            baseUrl: args.pageUrl)
        analyzeRule.setContent(args.body, baseUrl: args.pageUrl)
        _ = analyzeRule.setRedirectUrl(args.redirectUrl)
        analyzeRule.setNextChapterUrl(args.nextChapterUrl)
        analyzeRule.setChapter(args.context.chapter)

        var rawContent = analyzeRule.getString(args.context.contentRule.content)
        if !args.context.book.isAudio, !args.context.book.isVideo {
            rawContent = ContentParser.clean(rawContent)
        }

        var nextUrlList: [String] = []
        if getNextPageUrl, let nextUrlRule = args.context.contentRule.nextContentUrl, !nextUrlRule.isEmpty,
           let urls = analyzeRule.getStringList(nextUrlRule, isUrl: true) {
            for urlItem in urls {
                let trimmed = urlItem.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    nextUrlList.append(AnalyzeUrl.resolveAbsoluteUrl(trimmed, baseUrl: args.redirectUrl))
                }
            }
        }

        return (rawContent, nextUrlList)
    }
}
