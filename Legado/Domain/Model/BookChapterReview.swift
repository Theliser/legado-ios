import Foundation

/// 章节段评与评语领域模型 (对齐 Android Legado `io.legado.app.data.entities.BookChapterReview`)
public struct BookChapterReview: Codable, Equatable, Sendable {
    public var bookId: String
    public var chapterId: String
    public var summaryUrl: String
    public var reviewCount: Int
    public var reviews: [BookReviewItem]

    public init(
        bookId: String = "",
        chapterId: String = "",
        summaryUrl: String = "",
        reviewCount: Int = 0,
        reviews: [BookReviewItem] = []) {
        self.bookId = bookId
        self.chapterId = chapterId
        self.summaryUrl = summaryUrl
        self.reviewCount = reviewCount
        self.reviews = reviews
    }
}

/// 单条评语项
public struct BookReviewItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var author: String
    public var avatar: String?
    public var content: String
    public var postTime: String?
    public var voteUp: Int
    public var voteDown: Int

    public init(
        id: String = UUID().uuidString,
        author: String = "",
        avatar: String? = nil,
        content: String = "",
        postTime: String? = nil,
        voteUp: Int = 0,
        voteDown: Int = 0) {
        self.id = id
        self.author = author
        self.avatar = avatar
        self.content = content
        self.postTime = postTime
        self.voteUp = voteUp
        self.voteDown = voteDown
    }
}
