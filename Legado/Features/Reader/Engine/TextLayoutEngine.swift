import CoreText
import Foundation
import UIKit

/// 基于 CoreText 的高性能非阻塞分页排版引擎
public final class TextLayoutEngine: Sendable {
    public static let shared = TextLayoutEngine()

    public init() {}

    /// 将整章文本依据屏幕可视区域和排版配置精确切割为多个 ReaderPage
    public func paginate(
        chapterTitle: String,
        content: String,
        chapterIndex: Int,
        bounds: CGRect,
        config: ReaderConfig) -> [ReaderPage] {
        guard !content.isEmpty else {
            return [
                ReaderPage(
                    pageIndex: 0,
                    chapterIndex: chapterIndex,
                    chapterTitle: chapterTitle,
                    textRange: NSRange(location: 0, length: 0),
                    contentText: "本章内容为空"),
            ]
        }

        // 计算除去上下左右安全内边距的实际排版矩阵
        let renderWidth = max(bounds.width - config.horizontalMargin * 2, 100)
        let renderHeight = max(bounds.height - config.topMargin - config.bottomMargin, 100)
        let renderRect = CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)

        // 构造排版富文本
        let attrString = createAttributedString(
            title: chapterTitle,
            content: content,
            config: config)

        let framesetter = CTFramesetterCreateWithAttributedString(attrString as CFAttributedString)
        let path = CGPath(rect: renderRect, transform: nil)

        var pages: [ReaderPage] = []
        var textPos = 0
        let totalLength = attrString.length
        var pageIndex = 0

        while textPos < totalLength {
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: textPos, length: 0),
                path,
                nil)

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            if visibleRange.length == 0 {
                break
            }

            let nsRange = NSRange(location: visibleRange.location, length: visibleRange.length)
            let pageText = (attrString.string as NSString).substring(with: nsRange)

            pages.append(ReaderPage(
                pageIndex: pageIndex,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                textRange: nsRange,
                contentText: pageText))

            textPos += visibleRange.length
            pageIndex += 1
        }

        if pages.isEmpty {
            pages.append(ReaderPage(
                pageIndex: 0,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                textRange: NSRange(location: 0, length: 0),
                contentText: content))
        }

        return pages
    }

    /// 构造具备中文段落特征的排版富文本
    public func createAttributedString(
        title _: String,
        content: String,
        config: ReaderConfig) -> NSAttributedString {
        let font = config.fontFamily.uiFont(size: config.fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = config.lineSpacing
        paragraphStyle.paragraphSpacing = config.paragraphSpacing
        paragraphStyle.alignment = .justified // 中文两端对齐

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor(config.theme.textColor),
        ]

        return NSAttributedString(string: content, attributes: attributes)
    }
}
