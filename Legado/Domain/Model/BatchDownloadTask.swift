import Foundation

/// 批量离线缓存快捷选项
public enum BatchDownloadOption: String, CaseIterable, Identifiable, Sendable {
    case next50 = "后 50 章"
    case next100 = "后 100 章"
    case allUnread = "全部未读章节"
    case all = "全本书籍缓存"

    public var id: String {
        rawValue
    }
}

/// 批量下载状态
public enum BatchDownloadStatus: Equatable, Sendable {
    case idle
    case downloading
    case paused
    case completed
    case failed(String)
}

/// 离线缓存进度快照
public struct BatchDownloadProgress: Equatable, Sendable {
    public var bookUrl: String
    public var bookName: String
    public var totalChaptersToDownload: Int
    public var completedChaptersCount: Int
    public var currentChapterTitle: String?
    public var status: BatchDownloadStatus

    public init(
        bookUrl: String = "",
        bookName: String = "",
        totalChaptersToDownload: Int = 0,
        completedChaptersCount: Int = 0,
        currentChapterTitle: String? = nil,
        status: BatchDownloadStatus = .idle) {
        self.bookUrl = bookUrl
        self.bookName = bookName
        self.totalChaptersToDownload = totalChaptersToDownload
        self.completedChaptersCount = completedChaptersCount
        self.currentChapterTitle = currentChapterTitle
        self.status = status
    }

    public var progress: Double {
        guard totalChaptersToDownload > 0 else { return 0.0 }
        return min(1.0, Double(completedChaptersCount) / Double(totalChaptersToDownload))
    }

    public var percentage: Int {
        Int(progress * 100)
    }
}
