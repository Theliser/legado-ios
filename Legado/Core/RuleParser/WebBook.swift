import Foundation

/// 书源网络交互门面中枢 (对齐 Android Legado io.legado.app.model.webBook.WebBook.kt)
public struct WebBook: Sendable {
    public let httpClient: HTTPClientProtocol

    public init(httpClient: HTTPClientProtocol = HTTPClient.shared) {
        self.httpClient = httpClient
    }

    public func searchBookAwait(
        bookSource: BookSource,
        key: String,
        page: Int? = 1) async throws -> [SearchBook] {
        try await Self.searchBookAwait(
            bookSource: bookSource,
            key: key,
            page: page,
            httpClient: httpClient)
    }

    public func getBookInfoAwait(
        bookSource: BookSource,
        book: Book) async throws -> Book {
        var mutableBook = book
        return try await Self.getBookInfoAwait(
            bookSource: bookSource,
            book: &mutableBook,
            httpClient: httpClient)
    }

    public func getChapterListAwait(
        bookSource: BookSource,
        book: Book) async throws -> [Chapter] {
        try await Self.getChapterListAwait(
            bookSource: bookSource,
            book: book,
            httpClient: httpClient)
    }

    public func getContentAwait(
        bookSource: BookSource,
        book: Book,
        chapter: Chapter) async throws -> String {
        var mutableChapter = chapter
        return try await Self.getContentAwait(
            bookSource: bookSource,
            book: book,
            bookChapter: &mutableChapter,
            httpClient: httpClient)
    }
}

// MARK: - Static Implementations

public extension WebBook {
    /// 搜索书籍
    static func searchBookAwait(
        bookSource: BookSource,
        key: String,
        page: Int? = 1,
        filter: ((String, String, String?) -> Bool)? = nil,
        shouldBreak: ((Int) -> Bool)? = nil,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> [SearchBook] {
        guard let searchUrl = bookSource.searchUrl,
              !searchUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(
                domain: "WebBook",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "搜索 URL 不能为空"])
        }

        let ruleData = RuleData()
        let analyzeUrl = try AnalyzeUrl(
            mUrl: searchUrl,
            key: key,
            page: page,
            baseUrl: bookSource.bookSourceUrl,
            source: bookSource,
            ruleData: ruleData)

        var res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)
        checkLogin(source: bookSource, analyzeUrl: analyzeUrl, response: &res)

        return BookList.analyzeBookList(
            bookSource: bookSource,
            ruleData: ruleData,
            analyzeUrl: analyzeUrl,
            baseUrl: res.url,
            body: res.body,
            isSearch: true,
            isRedirect: res.isRedirect,
            filter: filter,
            shouldBreak: shouldBreak)
    }

    /// 发现书籍
    static func exploreBookAwait(
        bookSource: BookSource,
        url: String,
        page: Int? = 1,
        ruleData: RuleDataInterface = RuleData(),
        key: String? = nil,
        isSearch: Bool = false,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> [SearchBook] {
        let analyzeUrl = try AnalyzeUrl(
            mUrl: url,
            key: key,
            page: page,
            baseUrl: bookSource.bookSourceUrl,
            source: bookSource,
            ruleData: ruleData)

        var res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)
        checkLogin(source: bookSource, analyzeUrl: analyzeUrl, response: &res)

        return BookList.analyzeBookList(
            bookSource: bookSource,
            ruleData: ruleData,
            analyzeUrl: analyzeUrl,
            baseUrl: res.url,
            body: res.body,
            isSearch: isSearch)
    }

    /// 发现书籍并返回最终重定向 URL
    static func exploreBookWithResolvedUrl(
        bookSource: BookSource,
        url: String,
        page: Int? = 1,
        ruleData: RuleDataInterface = RuleData(),
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> (String, [SearchBook]) {
        let analyzeUrl = try AnalyzeUrl(
            mUrl: url,
            page: page,
            baseUrl: bookSource.bookSourceUrl,
            source: bookSource,
            ruleData: ruleData)

        var res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)
        checkLogin(source: bookSource, analyzeUrl: analyzeUrl, response: &res)

        let books = BookList.analyzeBookList(
            bookSource: bookSource,
            ruleData: ruleData,
            analyzeUrl: analyzeUrl,
            baseUrl: res.url,
            body: res.body,
            isSearch: false)
        return (res.url, books)
    }

    /// 获取书籍详情信息
    static func getBookInfoAwait(
        bookSource: BookSource,
        book: inout Book,
        canReName: Bool = true,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> Book {
        if !book.config.fixedType {
            book.removeAllBookType()
            book.addType(bookSource.getBookType())
        }

        if let infoHtml = book.infoHtml, !infoHtml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            BookInfo.analyzeBookInfo(
                bookSource: bookSource,
                book: &book,
                baseUrl: book.bookUrl,
                redirectUrl: book.bookUrl,
                body: infoHtml,
                canReName: canReName)
        } else {
            let analyzeUrl = try AnalyzeUrl(
                mUrl: book.bookUrl,
                baseUrl: bookSource.bookSourceUrl,
                source: bookSource,
                book: book)

            var res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)

            if let checkJs = bookSource.loginCheckJs, !checkJs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let modified = analyzeUrl.evalJS(checkJs, result: res) as? StrResponse {
                    res = modified
                }
            }

            BookInfo.analyzeBookInfo(
                bookSource: bookSource,
                book: &book,
                baseUrl: book.bookUrl,
                redirectUrl: res.url,
                body: res.body,
                canReName: canReName)
        }
        return book
    }

    /// 执行目录预处理 JS (preUpdateJs)
    static func runPreUpdateJs(bookSource: BookSource, book: Book) {
        var sourceMutable = bookSource
        let tocRule = sourceMutable.getTocRule()
        if let preUpdateJs = tocRule.preUpdateJs?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preUpdateJs.isEmpty {
            let engine = JSEngine()
            _ = engine.evaluate(script: preUpdateJs, bindings: [
                "book": book,
                "source": bookSource,
                "baseUrl": book.bookUrl,
            ])
        }
    }

    /// 获取书籍目录列表
    static func getChapterListAwait(
        bookSource: BookSource,
        book: Book,
        runPreJs: Bool = false,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> [Chapter] {
        var mutableBook = book
        if !mutableBook.config.fixedType {
            mutableBook.removeAllBookType()
            mutableBook.addType(bookSource.getBookType())
        }

        if runPreJs {
            runPreUpdateJs(bookSource: bookSource, book: mutableBook)
        }

        if mutableBook.bookUrl == mutableBook.tocUrl,
           let tocHtml = mutableBook.tocHtml,
           !tocHtml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try await BookChapterList.analyzeChapterList(
                bookSource: bookSource,
                book: mutableBook,
                baseUrl: mutableBook.tocUrl,
                redirectUrl: mutableBook.tocUrl,
                body: tocHtml,
                httpClient: httpClient)
        } else {
            let analyzeUrl = try AnalyzeUrl(
                mUrl: mutableBook.tocUrl.isEmpty ? mutableBook.bookUrl : mutableBook.tocUrl,
                baseUrl: mutableBook.bookUrl,
                source: bookSource,
                book: mutableBook)

            var res = try await analyzeUrl.getStrResponseAwait(httpClient: httpClient)
            checkLogin(source: bookSource, analyzeUrl: analyzeUrl, response: &res)

            return try await BookChapterList.analyzeChapterList(
                bookSource: bookSource,
                book: mutableBook,
                baseUrl: mutableBook.tocUrl.isEmpty ? mutableBook.bookUrl : mutableBook.tocUrl,
                redirectUrl: res.url,
                body: res.body,
                httpClient: httpClient)
        }
    }

    /// 获取章节正文内容
    static func getContentAwait(
        bookSource: BookSource,
        book: Book,
        bookChapter: inout Chapter,
        nextChapterUrl: String? = nil,
        needSave: Bool = true,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> String {
        var sourceMutable = bookSource
        let contentRule = sourceMutable.getContentRule()
        if contentRule.content?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            return bookChapter.url
        }

        if bookChapter.isVolume && bookChapter.url.hasPrefix(bookChapter.title) {
            return bookChapter.tag ?? ""
        }

        if bookChapter.url == book.bookUrl,
           let tocHtml = book.tocHtml,
           !tocHtml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ctx = BookContent.RequestContext(
                baseUrl: bookChapter.getAbsoluteURL(),
                redirectUrl: bookChapter.getAbsoluteURL(),
                nextChapterUrl: nextChapterUrl,
                needSave: needSave)
            return try await BookContent.analyzeContent(
                bookSource: bookSource,
                book: book,
                bookChapter: &bookChapter,
                body: tocHtml,
                context: ctx,
                httpClient: httpClient)
        } else {
            let analyzeUrl = try AnalyzeUrl(
                mUrl: bookChapter.getAbsoluteURL(),
                baseUrl: book.tocUrl.isEmpty ? book.bookUrl : book.tocUrl,
                source: bookSource,
                chapter: bookChapter,
                book: book)

            var res = try await analyzeUrl.getStrResponseAwait(
                httpClient: httpClient,
                jsStr: contentRule.webJs,
                sourceRegex: contentRule.sourceRegex)
            checkLogin(source: bookSource, analyzeUrl: analyzeUrl, response: &res)

            let ctx = BookContent.RequestContext(
                baseUrl: bookChapter.getAbsoluteURL(),
                redirectUrl: res.url,
                nextChapterUrl: nextChapterUrl,
                needSave: needSave)
            return try await BookContent.analyzeContent(
                bookSource: bookSource,
                book: book,
                bookChapter: &bookChapter,
                body: res.body,
                context: ctx,
                httpClient: httpClient)
        }
    }

    /// 精准搜索单本书籍
    static func preciseSearchAwait(
        bookSource: BookSource,
        name: String,
        author: String,
        httpClient: HTTPClientProtocol = HTTPClient.shared) async throws -> Book {
        let results = try await searchBookAwait(
            bookSource: bookSource,
            key: name,
            filter: { fName, fAuthor, _ in
                fName == name && (author.isEmpty || fAuthor == author)
            },
            shouldBreak: { $0 > 0 },
            httpClient: httpClient)

        if let first = results.first {
            return first.toBook()
        }
        throw NSError(
            domain: "WebBook",
            code: -404,
            userInfo: [NSLocalizedDescriptionKey: "未搜索到 \(name)(\(author)) 书籍"])
    }

    private static func checkLogin(source: BookSource, analyzeUrl: AnalyzeUrl, response: inout StrResponse) {
        if let checkJs = source.loginCheckJs,
           !checkJs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let modified = analyzeUrl.evalJS(checkJs, result: response) as? StrResponse {
            response = modified
        }
    }
}
