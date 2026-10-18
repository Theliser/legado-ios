import Foundation

/// 本地 TXT 章节智能解析实体
public struct ParsedTxtChapter: Equatable, Sendable {
    public let title: String
    public let content: String
    public let index: Int

    public init(title: String, content: String, index: Int) {
        self.title = title
        self.content = content
        self.index = index
    }
}

/// 本地 TXT 小说智能目录与正则分卷解析引擎
public enum TxtTocParser {
    /// 默认通用章节标题正则表达式 (对标 Legado Android 官方 txtTocRule)
    public static let defaultChapterPattern =
        "^[ \\t　]{0,4}(?:序章|楔子|正文(?!完|结)|终章|后记|尾声|番外|" +
        "第\\s{0,4}[\\d〇零一二两三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]+?\\s{0,4}" +
        "(?:章|节(?!课)|卷|集(?![合和])|部(?![分赛游])|篇(?!张)|回|话)).{0,40}$"

    /// 解析全文并智能切分为章节单元
    public static func parse(
        text: String,
        customPattern: String? = nil) -> [ParsedTxtChapter] {
        let pattern = customPattern ?? defaultChapterPattern
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return fallbackChunkSplit(text: text)
        }

        let lines = text.components(separatedBy: .newlines)
        var chapters: [ParsedTxtChapter] = []

        var currentTitle: String?
        var currentLines: [String] = []
        var chapterIndex = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                currentLines.append("")
                continue
            }

            let range = NSRange(location: 0, length: line.utf16.count)
            let isMatch = regex.firstMatch(in: line, options: [], range: range) != nil

            if isMatch {
                // 如果之前有收集内容，归入前一章
                if let title = currentTitle {
                    let content = currentLines
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    chapters.append(ParsedTxtChapter(title: title, content: content, index: chapterIndex))
                    chapterIndex += 1
                } else if !currentLines.isEmpty {
                    // 第一章之前的前言/序文
                    let prefaceContent = currentLines
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !prefaceContent.isEmpty {
                        chapters.append(ParsedTxtChapter(title: "前言", content: prefaceContent, index: chapterIndex))
                        chapterIndex += 1
                    }
                }

                currentTitle = trimmed
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        // 追加最后一章
        if let title = currentTitle {
            let content = currentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            chapters.append(ParsedTxtChapter(title: title, content: content, index: chapterIndex))
        }

        // 如果未匹配到足够章节（如短篇或非标准标题），进行保底按长度智能分节
        if chapters.isEmpty {
            return fallbackChunkSplit(text: text)
        }

        return chapters
    }

    /// 保底分卷：按每 4000 字符切分为连续小节
    private static func fallbackChunkSplit(text: String) -> [ParsedTxtChapter] {
        let chunkSize = 4000
        var chapters: [ParsedTxtChapter] = []
        var currentIndex = text.startIndex
        var partIndex = 1

        while currentIndex < text.endIndex {
            let nextIndex = text.index(currentIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[currentIndex ..< nextIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chapters.append(ParsedTxtChapter(
                    title: "第 \(partIndex) 节",
                    content: chunk,
                    index: partIndex - 1))
                partIndex += 1
            }
            currentIndex = nextIndex
        }

        if chapters.isEmpty {
            chapters.append(ParsedTxtChapter(title: "正文", content: text, index: 0))
        }

        return chapters
    }
}
