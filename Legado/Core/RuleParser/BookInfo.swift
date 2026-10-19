import Foundation

/// 详情页规则提取引擎 (对齐 Android Legado BookInfo.kt)
public enum BookInfo {
    @discardableResult
    public static func analyzeBookInfo(
        book: Book,
        body: String?,
        bookSource: BookSource,
        baseUrl: String,
        redirectUrl: String,
        canReName: Bool = false) async throws -> Book {
        var mutableBook = book
        analyzeBookInfo(
            bookSource: bookSource,
            book: &mutableBook,
            baseUrl: baseUrl,
            redirectUrl: redirectUrl,
            body: body,
            canReName: canReName)
        return mutableBook
    }

    public static func analyzeBookInfo(
        bookSource: BookSource,
        book: inout Book,
        baseUrl: String,
        redirectUrl: String,
        body: String?,
        canReName: Bool = false) {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let analyzeRule = AnalyzeRule(book: book, source: bookSource, baseUrl: baseUrl)
        analyzeRule.setContent(body, baseUrl: baseUrl)
        _ = analyzeRule.setRedirectUrl(redirectUrl)

        var sourceMutable = bookSource
        let infoRule = sourceMutable.getBookInfoRule()

        // 1. 初始化规则
        if let initRule = infoRule.bookInfoInit?.trimmingCharacters(in: .whitespacesAndNewlines),
           !initRule.isEmpty, let initElement = analyzeRule.getElement(initRule) {
            analyzeRule.setContent(initElement, baseUrl: baseUrl)
        }

        let renameConfig = infoRule.canReName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowRename = canReName && (renameConfig == nil || !renameConfig!.isEmpty)

        extractBasicInfo(analyzeRule: analyzeRule, infoRule: infoRule, book: &book, allowRename: allowRename)
        extractAdditionalInfo(analyzeRule: analyzeRule, infoRule: infoRule, book: &book)
    }

    private static func extractBasicInfo(
        analyzeRule: AnalyzeRule,
        infoRule: BookInfoRule,
        book: inout Book,
        allowRename: Bool) {
        let extractedName = analyzeRule.getString(infoRule.name).trimmingCharacters(in: .whitespacesAndNewlines)
        if !extractedName.isEmpty, allowRename || book.name.isEmpty {
            book.name = extractedName
        }

        let extractedAuthor = analyzeRule.getString(infoRule.author).trimmingCharacters(in: .whitespacesAndNewlines)
        if !extractedAuthor.isEmpty, allowRename || book.author.isEmpty {
            book.author = extractedAuthor
        }

        if let kindRule = infoRule.kind, !kindRule.isEmpty,
           let kinds = analyzeRule.getStringList(kindRule), !kinds.isEmpty {
            book.kind = kinds.joined(separator: ",")
        }
    }

    private static func extractAdditionalInfo(
        analyzeRule: AnalyzeRule,
        infoRule: BookInfoRule,
        book: inout Book) {
        let wordCountStr = analyzeRule.getString(infoRule.wordCount).trimmingCharacters(in: .whitespacesAndNewlines)
        if !wordCountStr.isEmpty {
            book.wordCount = wordCountStr
        }

        let lastChapterStr = analyzeRule.getString(infoRule.lastChapter).trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastChapterStr.isEmpty {
            book.latestChapterTitle = lastChapterStr
            book.latestChapterTime = Int64(Date().timeIntervalSince1970 * 1000)
        }

        let introStr = analyzeRule.getString(infoRule.intro).trimmingCharacters(in: .whitespacesAndNewlines)
        if !introStr.isEmpty {
            book.intro = introStr
        }

        let coverStr = analyzeRule.getString(infoRule.coverUrl, isUrl: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !coverStr.isEmpty {
            book.coverUrl = coverStr
        }

        let tocStr = analyzeRule.getString(infoRule.tocUrl, isUrl: true)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !tocStr.isEmpty {
            book.tocUrl = tocStr
        } else if book.tocUrl.isEmpty {
            book.tocUrl = book.bookUrl
        }
    }
}
