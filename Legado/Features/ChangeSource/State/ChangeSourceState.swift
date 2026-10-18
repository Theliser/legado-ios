import Foundation

/// 换源单向数据流不可变状态
public struct ChangeSourceState: ViewState, Sendable {
    public var book: Book
    public var currentChapterTitle: String?
    public var currentChapterIndex: Int
    public var candidates: [ChangeSourceCandidate]
    public var isSearching: Bool
    public var isSwitching: Bool
    public var selectedCandidateId: String?
    public var toastMessage: String?

    public init(
        book: Book,
        currentChapterTitle: String? = nil,
        currentChapterIndex: Int = 0,
        candidates: [ChangeSourceCandidate] = [],
        isSearching: Bool = false,
        isSwitching: Bool = false,
        selectedCandidateId: String? = nil,
        toastMessage: String? = nil) {
        self.book = book
        self.currentChapterTitle = currentChapterTitle
        self.currentChapterIndex = currentChapterIndex
        self.candidates = candidates
        self.isSearching = isSearching
        self.isSwitching = isSwitching
        self.selectedCandidateId = selectedCandidateId
        self.toastMessage = toastMessage
    }
}
