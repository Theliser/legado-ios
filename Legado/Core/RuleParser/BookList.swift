import Foundation

/// 搜索与发现列表规则提取引擎 (对齐 Android Legado BookList.kt)
public enum BookList {
    public static func analyzeBookList(
        body: String?,
        bookSource: BookSource,
        rule _: BookListRule? = nil,
        baseUrl: String,
        redirectUrl _: String = "",
        isSearch: Bool = true) async throws -> [SearchResult] {
        let analyzeUrl = try AnalyzeUrl(rawUrl: baseUrl)
        return analyzeBookList(
            bookSource: bookSource,
            analyzeUrl: analyzeUrl,
            baseUrl: baseUrl,
            body: body,
            isSearch: isSearch)
    }

    public static func analyzeBookList(
        bookSource: BookSource,
        ruleData _: RuleDataInterface = RuleData(),
        analyzeUrl _: AnalyzeUrl,
        baseUrl: String,
        body: String?,
        isSearch: Bool = true,
        isRedirect: Bool = false,
        filter: ((String, String, String?) -> Bool)? = nil,
        shouldBreak: ((Int) -> Bool)? = nil) -> [SearchResult] {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var sourceMutable = bookSource
        var bookList: [SearchResult] = []
        let analyzeRule = AnalyzeRule(source: bookSource, baseUrl: baseUrl)
        analyzeRule.setContent(body, baseUrl: baseUrl)
        analyzeRule.setRedirectUrl(baseUrl)

        // 1. 如果配置了 bookUrlPattern 且当前 URL 匹配详情页正则，直接按详情页提取单本结果 (对齐 Android BookList.kt:62)
        if isSearch, isDirectDetailPage(bookSource: bookSource, baseUrl: baseUrl),
           let single = extractSingleDetailItem(
               bookSource: bookSource,
               body: body,
               baseUrl: baseUrl,
               isRedirect: isRedirect,
               filter: filter) {
            return [single]
        }

        // 2. 选择规则与处理正反序
        let activeInfo = resolveActiveRule(source: &sourceMutable, isSearch: isSearch)
        let collections = activeInfo.listRule.isEmpty ? [] : analyzeRule.getElements(activeInfo.listRule)

        // 3. 如果提取列表为空且未配置 bookUrlPattern，尝试按单本详情页回退解析 (对齐 Android BookList.kt:100)
        if collections.isEmpty, bookSource.bookUrlPattern == nil || bookSource.bookUrlPattern!.isEmpty {
            if let single = extractSingleDetailItem(
                bookSource: bookSource,
                body: body,
                baseUrl: baseUrl,
                isRedirect: isRedirect,
                filter: filter) {
                return [single]
            }
            return []
        }

        // 4. 遍历列表提取书籍项
        for item in collections {
            if let searchItem = extractSearchItem(
                element: item,
                rule: activeInfo.rule,
                bookSource: bookSource,
                baseUrl: baseUrl,
                filter: filter) {
                bookList.append(searchItem)
            }
            if let shouldBreak, shouldBreak(bookList.count) {
                break
            }
        }

        // 5. 去重与按序整理
        var seenUrls = Set<String>()
        var deduplicated: [SearchResult] = []
        for book in bookList where !seenUrls.contains(book.bookUrl) {
            seenUrls.insert(book.bookUrl)
            deduplicated.append(book)
        }

        if activeInfo.reverse {
            deduplicated.reverse()
        }

        return deduplicated
    }

    private struct ActiveRuleInfo {
        let rule: BookListRule
        let listRule: String
        let reverse: Bool
    }

    private static func isDirectDetailPage(bookSource: BookSource, baseUrl: String) -> Bool {
        guard let pattern = bookSource.bookUrlPattern,
              !pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        return regex.firstMatch(in: baseUrl, range: NSRange(baseUrl.startIndex..., in: baseUrl)) != nil
    }

    private static func resolveActiveRule(
        source: inout BookSource,
        isSearch: Bool) -> ActiveRuleInfo {
        let searchRule = source.getSearchRule()
        let exploreRule = source.getExploreRule()
        let activeRule: BookListRule
        let rawRule: String

        if isSearch {
            activeRule = searchRule
            rawRule = searchRule.bookList ?? ""
        } else if let expList = exploreRule.bookList, !expList.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeRule = exploreRule
            rawRule = expList
        } else {
            activeRule = searchRule
            rawRule = searchRule.bookList ?? ""
        }

        var reverse = false
        var cleanRule = rawRule.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanRule.hasPrefix("-") {
            reverse = true
            cleanRule = String(cleanRule.dropFirst())
        } else if cleanRule.hasPrefix("+") {
            cleanRule = String(cleanRule.dropFirst())
        }
        return ActiveRuleInfo(rule: activeRule, listRule: cleanRule, reverse: reverse)
    }

    private static func extractSingleDetailItem(
        bookSource: BookSource,
        body: String,
        baseUrl: String,
        isRedirect _: Bool,
        filter: ((String, String, String?) -> Bool)?) -> SearchResult? {
        var tempBook = Book(
            bookUrl: baseUrl,
            origin: bookSource.bookSourceUrl,
            name: "",
            author: "")
        BookInfo.analyzeBookInfo(
            bookSource: bookSource,
            book: &tempBook,
            baseUrl: baseUrl,
            redirectUrl: baseUrl,
            body: body)

        guard !tempBook.name.isEmpty else { return nil }
        if let filter, !filter(tempBook.name, tempBook.author, tempBook.kind) {
            return nil
        }

        return SearchResult(
            bookUrl: baseUrl,
            origin: bookSource.bookSourceUrl,
            originName: bookSource.bookSourceName,
            originOrder: bookSource.customOrder ?? 0,
            name: tempBook.name,
            author: tempBook.author,
            kind: tempBook.kind,
            coverUrl: tempBook.coverUrl,
            intro: tempBook.intro,
            latestChapterTitle: tempBook.latestChapterTitle,
            wordCount: tempBook.wordCount,
            responseTimeMs: 0)
    }

    private static func extractSearchItem(
        element: Any,
        rule: BookListRule,
        bookSource: BookSource,
        baseUrl: String,
        filter: ((String, String, String?) -> Bool)?) -> SearchResult? {
        let itemAnalyzer = AnalyzeRule(source: bookSource, baseUrl: baseUrl)
        itemAnalyzer.setContent(element, baseUrl: baseUrl)

        let name = itemAnalyzer.getString(rule.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let bookUrl = itemAnalyzer.getString(rule.bookUrl, isUrl: true).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bookUrl.isEmpty else { return nil }

        let author = itemAnalyzer.getString(rule.author).trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = itemAnalyzer.getString(rule.kind).trimmingCharacters(in: .whitespacesAndNewlines)
        let cover = itemAnalyzer.getString(rule.coverUrl, isUrl: true).trimmingCharacters(in: .whitespacesAndNewlines)
        let intro = itemAnalyzer.getString(rule.intro).trimmingCharacters(in: .whitespacesAndNewlines)
        let lastChapter = itemAnalyzer.getString(rule.lastChapter).trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = itemAnalyzer.getString(rule.wordCount).trimmingCharacters(in: .whitespacesAndNewlines)

        if let filter, !filter(name, author, kind.isEmpty ? nil : kind) {
            return nil
        }

        return SearchResult(
            bookUrl: bookUrl,
            origin: bookSource.bookSourceUrl,
            originName: bookSource.bookSourceName,
            originOrder: bookSource.customOrder ?? 0,
            name: name,
            author: author,
            kind: kind.isEmpty ? nil : kind,
            coverUrl: cover.isEmpty ? nil : cover,
            intro: intro.isEmpty ? nil : intro,
            latestChapterTitle: lastChapter.isEmpty ? nil : lastChapter,
            wordCount: wordCount.isEmpty ? nil : wordCount,
            responseTimeMs: 0)
    }
}
