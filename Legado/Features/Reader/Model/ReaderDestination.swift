import Foundation

/// 阅读器目标导航模型
public struct ReaderDestination: Identifiable, Sendable {
    public let id: String
    public let book: Book
    public let chapterIndex: Int

    public init(book: Book, chapterIndex: Int? = nil) {
        let chapter = chapterIndex ?? book.durChapterIndex
        self.id = "\(book.bookUrl)_\(chapter)"
        self.book = book
        self.chapterIndex = chapter
    }
}
