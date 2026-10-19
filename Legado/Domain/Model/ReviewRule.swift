import Foundation

/// 段评与章评规则 (对齐 Android Legado ReviewRule.kt)
public struct ReviewRule: Codable, Equatable, Sendable {
    public var reviewUrl: String?
    public var avatarRule: String?
    public var contentRule: String?
    public var postTimeRule: String?
    public var reviewQuoteUrl: String?
    public var voteUpUrl: String?
    public var voteDownUrl: String?
    public var postReviewUrl: String?
    public var postQuoteUrl: String?
    public var deleteUrl: String?

    public init(
        reviewUrl: String? = nil,
        avatarRule: String? = nil,
        contentRule: String? = nil,
        postTimeRule: String? = nil,
        reviewQuoteUrl: String? = nil,
        voteUpUrl: String? = nil,
        voteDownUrl: String? = nil,
        postReviewUrl: String? = nil,
        postQuoteUrl: String? = nil,
        deleteUrl: String? = nil) {
        self.reviewUrl = reviewUrl
        self.avatarRule = avatarRule
        self.contentRule = contentRule
        self.postTimeRule = postTimeRule
        self.reviewQuoteUrl = reviewQuoteUrl
        self.voteUpUrl = voteUpUrl
        self.voteDownUrl = voteDownUrl
        self.postReviewUrl = postReviewUrl
        self.postQuoteUrl = postQuoteUrl
        self.deleteUrl = deleteUrl
    }
}

public typealias RuleReview = ReviewRule
