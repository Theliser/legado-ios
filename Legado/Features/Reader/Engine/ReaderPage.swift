import Foundation
import UIKit

/// 单页 CoreText 排版结果实体
public struct ReaderPage: Identifiable, Equatable, Sendable {
    public var id: String {
        "\(chapterIndex)_\(pageIndex)"
    }

    public let pageIndex: Int
    public let chapterIndex: Int
    public let chapterTitle: String
    public let textRange: NSRange
    public let contentText: String

    public init(
        pageIndex: Int,
        chapterIndex: Int,
        chapterTitle: String,
        textRange: NSRange,
        contentText: String) {
        self.pageIndex = pageIndex
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.textRange = textRange
        self.contentText = contentText
    }
}
