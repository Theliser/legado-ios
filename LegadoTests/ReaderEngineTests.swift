import CoreGraphics
import Foundation
@testable import Legado
import SwiftUI
import Testing

@Suite("Reader Engine Suite")
struct ReaderEngineTests {
    @Test("Test ContentParser Text Cleaning and Chinese Indentation")
    func contentParserCleaning() {
        let parser = ContentParser.shared
        let rawHtmlContent = """
        <p>第一段：这里是小说正文内容。<br/>中间包含了换行标签。</p>
        <div>第二段：&nbsp;&nbsp;包含HTML实体 &quot;引号&quot; 和 &amp; 符号。</div>
        <script>alert("ad");</script>
        <p>第三段：最后一段内容。</p>
        """

        let cleaned = parser.cleanContent(rawHtmlContent)

        // 验证标签已被清理
        #expect(!cleaned.contains("<p>"))
        #expect(!cleaned.contains("</p>"))
        #expect(!cleaned.contains("<br/>"))
        #expect(!cleaned.contains("alert"))

        // 验证实体替换
        #expect(cleaned.contains("\"引号\""))
        #expect(cleaned.contains("&"))

        // 验证中文首行缩进
        let lines = cleaned.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        #expect(lines.count == 4)
        for line in lines {
            #expect(line.hasPrefix("\u{3000}\u{3000}"))
        }
    }

    @Test("Test TextLayoutEngine CoreText Pagination")
    func textLayoutEnginePagination() {
        let engine = TextLayoutEngine.shared
        let sampleText = """
        　　夜幕降临，微凉的晚风吹拂过荒野，带来了远处不知名野兽的低沉吼声。
        　　卢米安站在高耸的崖壁顶端，俯瞰着下方若隐若现的村落灯火。在这个充满神秘与超凡的世界里，每一个看似宁静的黑夜背后，都潜藏着凡人难以窥见的波诡云谲。
        　　他下意识地摸了摸胸前的银质吊坠，冰冷的金属触感让他狂躁的心绪稍微平复了一些。根据那位神秘女士的指引，只要在特定的星象下完成仪式，就能真正迈入第一序列。
        　　但仪式所需要的祭品并不简单，除了罕见的灵界生物毛发，还需要一份真正直面疯狂与恐惧的勇气。
        　　狂风渐起，天空中厚重的铅云缓缓移动，露出了那一弯猩红如血的残月。命运的齿轮，已在此刻悄然转动。
        """

        var config = ReaderConfig.defaultConfig
        config.fontSize = 18
        config.lineSpacing = 6

        // 模拟标准 iPhone 屏幕尺寸排版容器 (宽360, 高600)
        let bounds = CGRect(x: 0, y: 0, width: 360, height: 600)
        let pages = engine.paginate(
            chapterTitle: "第一章 宿命之始",
            content: sampleText,
            chapterIndex: 0,
            bounds: bounds,
            config: config)

        #expect(!pages.isEmpty)
        #expect(pages.count >= 1)

        for (index, page) in pages.enumerated() {
            #expect(page.pageIndex == index)
            #expect(!page.contentText.isEmpty)
            #expect(page.textRange.length > 0)
        }

        // 验证第一页文本与起始字符一致
        if let firstPage = pages.first {
            #expect(firstPage.contentText.contains("夜幕降临"))
        }
    }

    @Test("Test ReaderConfig Theme and Adjustments")
    func readerConfigThemeAndAdjustments() {
        var config = ReaderConfig.defaultConfig
        #expect(config.fontSize == 19)
        #expect(config.theme == .paper)

        // 调整字号
        config.fontSize += 2
        #expect(config.fontSize == 21)

        // 切换主题
        config.theme = .dark
        #expect(config.theme.isDark == true)
        #expect(config.theme.backgroundColor == Color(red: 0.14, green: 0.14, blue: 0.16))
    }

    @Test("Test ReaderState Page Navigation Logic")
    func readerStateNavigation() {
        let dummyBook = Book(
            bookUrl: "https://example.com/book/1",
            origin: "https://example.com",
            name: "测试阅读书籍",
            author: "测试作者")

        var state = ReaderState(book: dummyBook, currentChapterIndex: 0)
        #expect(state.currentPageIndex == 0)
        #expect(state.currentPage == nil)

        // 模拟填入页面
        let page1 = ReaderPage(
            pageIndex: 0,
            chapterIndex: 0,
            chapterTitle: "第一章",
            textRange: NSRange(location: 0, length: 2),
            contentText: "页1")
        let page2 = ReaderPage(
            pageIndex: 1,
            chapterIndex: 0,
            chapterTitle: "第一章",
            textRange: NSRange(location: 2, length: 2),
            contentText: "页2")
        state.pages = [page1, page2]

        #expect(state.currentPage?.contentText == "页1")

        state.currentPageIndex = 1
        #expect(state.currentPage?.contentText == "页2")
    }
}
