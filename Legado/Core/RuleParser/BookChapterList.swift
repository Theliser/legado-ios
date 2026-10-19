import Foundation

/// 章节目录提取与分页引擎 (对齐 Android Legado BookChapterList.kt)
public enum BookChapterList {
    private struct PageContext {
        let book: Book
        let baseUrl: String
        let redirectUrl: String
        let body: String
        let tocRule: TocRule
        let listRule: String
        let bookSource: BookSource
    }

    public static func analyzeChapterList(
        bookSource: BookSource,
        book: Book,
        baseUrl: String,
        redirectUrl: String,
        body: String?,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> [Chapter] {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var sourceMutable = bookSource
        let tocRule = sourceMutable.getTocRule()
        let (rawListRule, reverse) = parseRuleDirection(tocRule.chapterList ?? "")

        let fetchArgs = FetchArgs(
            bookSource: bookSource,
            book: book,
            baseUrl: baseUrl,
            redirectUrl: redirectUrl,
            initialBody: body,
            tocRule: tocRule,
            rawListRule: rawListRule,
            httpClient: httpClient)
        var chapterList = try await fetchAllPageChapters(args: fetchArgs)

        if reverse {
            chapterList.reverse()
        }

        var deduplicated = deduplicateChapters(chapterList)
        applyFormatJs(to: &deduplicated, tocRule: tocRule, bookSource: bookSource, baseUrl: baseUrl)
        return deduplicated
    }

    private static func parseRuleDirection(_ raw: String) -> (rule: String, reverse: Bool) {
        if raw.hasPrefix("-") {
            return (String(raw.dropFirst()), true)
        } else if raw.hasPrefix("+") {
            return (String(raw.dropFirst()), false)
        }
        return (raw, false)
    }

    private struct FetchArgs {
        let bookSource: BookSource
        let book: Book
        let baseUrl: String
        let redirectUrl: String
        let initialBody: String
        let tocRule: TocRule
        let rawListRule: String
        let httpClient: HTTPClientProtocol
    }

    private static func fetchAllPageChapters(args: FetchArgs) async throws -> [Chapter] {
        var chapterList: [Chapter] = []
        var nextUrlList: Set<String> = [args.redirectUrl]
        var currentUrl = args.redirectUrl
        var currentBody = args.initialBody
        var pageCount = 0
        let maxPages = 50

        while pageCount < maxPages {
            pageCount += 1
            let ctx = PageContext(
                book: args.book,
                baseUrl: currentUrl,
                redirectUrl: currentUrl,
                body: currentBody,
                tocRule: args.tocRule,
                listRule: args.rawListRule,
                bookSource: args.bookSource)
            let (pageChapters, nextUrls) = parseSinglePage(context: ctx)
            chapterList.append(contentsOf: pageChapters)

            guard let nextUrl = nextUrls.first, !nextUrl.isEmpty, !nextUrlList.contains(nextUrl) else {
                break
            }

            nextUrlList.insert(nextUrl)
            currentUrl = nextUrl

            let nextRequest = try AnalyzeUrl(
                rawUrl: nextUrl,
                baseUrl: args.baseUrl,
                headerJson: args.bookSource.header,
                source: args.bookSource,
                book: args.book)

            currentBody = try await args.httpClient.fetch(analyzeUrl: nextRequest)
        }
        return chapterList
    }

    private static func deduplicateChapters(_ chapters: [Chapter]) -> [Chapter] {
        var seenUrls = Set<String>()
        var deduplicated: [Chapter] = []
        for (index, chapter) in chapters.enumerated() where !seenUrls.contains(chapter.url) {
            seenUrls.insert(chapter.url)
            var indexed = chapter
            indexed.index = index
            deduplicated.append(indexed)
        }
        return deduplicated
    }

    private static func applyFormatJs(
        to chapters: inout [Chapter],
        tocRule: TocRule,
        bookSource: BookSource,
        baseUrl: String) {
        guard let formatJs = tocRule.formatJs, !formatJs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let engine = JSEngine()
        for index in 0 ..< chapters.count {
            let chapter = chapters[index]
            let formatted = engine.evaluate(script: formatJs, bindings: [
                "index": index + 1,
                "title": chapter.title,
                "chapter": chapter,
                "source": bookSource,
                "baseUrl": baseUrl,
            ])?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let formatted, !formatted.isEmpty {
                chapters[index].title = formatted
            }
        }
    }

    private static func parseSinglePage(context: PageContext) -> ([Chapter], [String]) {
        let analyzeRule = AnalyzeRule(book: context.book, source: context.bookSource, baseUrl: context.baseUrl)
        analyzeRule.setContent(context.body, baseUrl: context.baseUrl)
        analyzeRule.setRedirectUrl(context.redirectUrl)

        let elements = analyzeRule.getElements(context.listRule)
        var chapters: [Chapter] = []

        for element in elements {
            let itemAnalyzer = AnalyzeRule(book: context.book, source: context.bookSource, baseUrl: context.baseUrl)
            itemAnalyzer.setContent(element, baseUrl: context.baseUrl)

            let title = itemAnalyzer.getString(context.tocRule.chapterName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let url = itemAnalyzer.getString(
                context.tocRule.chapterUrl,
                isUrl: true).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { continue }

            let isVipStr = itemAnalyzer.getString(context.tocRule.isVip).lowercased()
            let isVip = isVipStr == "true" || isVipStr == "1"

            chapters.append(Chapter(
                bookUrl: context.book.bookUrl,
                title: title,
                url: url,
                index: chapters.count,
                isVip: isVip))
        }

        var nextUrls: [String] = []
        if let nextRule = context.tocRule.nextTocUrl, !nextRule.isEmpty,
           let list = analyzeRule.getStringList(nextRule, isUrl: true) {
            for item in list where item != context.redirectUrl && !item.isEmpty {
                nextUrls.append(item)
            }
        }

        return (chapters, nextUrls)
    }
}
