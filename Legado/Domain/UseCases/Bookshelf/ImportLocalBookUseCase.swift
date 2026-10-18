import Foundation

/// 本地书籍导入用例 (支持 TXT 智能分卷解析与持久化)
public final class ImportLocalBookUseCase: Sendable {
    private let bookRepository: BookRepository
    private let bookCacheRepository: BookCacheRepository

    public init(
        bookRepository: BookRepository,
        bookCacheRepository: BookCacheRepository) {
        self.bookRepository = bookRepository
        self.bookCacheRepository = bookCacheRepository
    }

    /// 导入本地文件至书架
    public func execute(fileUrl: URL) async throws -> Book {
        let isAccessing = fileUrl.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileUrl.stopAccessingSecurityScopedResource()
            }
        }

        let fileData = try Data(contentsOf: fileUrl)
        let rawFileName = fileUrl.deletingPathExtension().lastPathComponent
        let cleanedTitle = cleanBookTitle(rawFileName)

        // 字符编码自适应探测 (UTF-8 / GBK / Big5)
        let content = CharsetDetector.decode(data: fileData)
        guard !content.isEmpty else {
            throw BookSourceParseError.invalidData
        }

        // 智能正则切分章节
        let parsedChapters = TxtTocParser.parse(text: content)
        guard !parsedChapters.isEmpty else {
            throw BookSourceParseError.invalidData
        }

        let bookUrl = "local://\(UUID().uuidString)"
        let book = Book(
            bookUrl: bookUrl,
            tocUrl: bookUrl,
            origin: "local",
            originName: "本地书籍",
            name: cleanedTitle,
            author: "本地导入",
            durChapterTitle: parsedChapters.first?.title,
            durChapterIndex: 0,
            durChapterTime: Int64(Date().timeIntervalSince1970 * 1000),
            totalChapterNum: parsedChapters.count)

        let chapters = parsedChapters.map { parsed in
            Chapter(
                url: "\(bookUrl)/\(parsed.index)",
                title: parsed.title,
                bookUrl: bookUrl,
                index: parsed.index)
        }

        // 持久化各章节内容至磁盘离线缓存
        for parsed in parsedChapters {
            try? bookCacheRepository.saveChapterContent(
                bookUrl: bookUrl,
                index: parsed.index,
                content: parsed.content)
        }

        // 持久化目录与书籍信息
        try await bookRepository.saveChapters(chapters, for: bookUrl)
        try await bookRepository.saveBook(book)

        return book
    }

    /// 净化书名文件名 (剔除常见网文标签如 [全本]、(校对版))
    private func cleanBookTitle(_ rawName: String) -> String {
        var name = rawName
        let tagsToRemove = [
            "\\[.*?\\]",
            "\\(.*?\\)",
            "【.*?】",
            "（.*?）",
            "全本",
            "精校",
            "校对版",
            "完整版",
            "精校版",
        ]
        for pattern in tagsToRemove {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                name = regex.stringByReplacingMatches(
                    in: name,
                    options: [],
                    range: NSRange(location: 0, length: name.utf16.count),
                    withTemplate: "")
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? rawName : trimmed
    }
}
