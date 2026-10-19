import Foundation
@testable import Legado
import Testing

@Suite("QueryTTF and Advanced Source Engine Suite")
struct QueryTTFTests {
    @Test("Test Blank Unicode Identification")
    func blankUnicode() {
        guard let dummyFont = makeMinimalTTFData(),
              let ttf = QueryTTF(data: dummyFont) else {
            Issue.record("Failed to create QueryTTF from minimal font data")
            return
        }

        #expect(ttf.isBlankUnicode(0x0020)) // Space
        #expect(ttf.isBlankUnicode(0x0009)) // Tab
        #expect(ttf.isBlankUnicode(0x3000) == false) // Ideographic Space
        #expect(ttf.isBlankUnicode(0x00A0)) // No-Break Space
        #expect(ttf.isBlankUnicode(0x200B)) // Zero Width Space
        #expect(ttf.isBlankUnicode(0x4E00) == false) // '一'
    }

    @Test("Test Minimal TrueType Font Binary Parsing")
    func minimalTTFParsing() {
        guard let fontData = makeMinimalTTFData() else {
            Issue.record("Failed to create font data")
            return
        }

        guard let ttf = QueryTTF(data: fontData) else {
            Issue.record("Failed to parse TTF")
            return
        }

        // 验证 cmap 映射 0xEA01 -> glyphId 1
        let glyphId = ttf.getGlyfIdByUnicode(0xEA01)
        #expect(glyphId == 1)

        // 验证轮廓数据提取
        let glyfStr = ttf.getGlyfById(1)
        #expect(glyfStr != nil)

        let glyfByUnicode = ttf.getGlyfByUnicode(0xEA01)
        #expect(glyfByUnicode == glyfStr)

        let unicodeBack = ttf.getUnicodeByGlyf(glyfStr ?? "")
        #expect(unicodeBack == 0xEA01)
    }

    @Test("Test Font Decryption and Character Replacement Algorithm")
    func fontReplacementAlgorithm() {
        guard let errorFontData = makeMinimalTTFData(unicodeCode: 0xEA01, x1: 10, y1: 20),
              let correctFontData = makeMinimalTTFData(unicodeCode: 0x6211, x1: 10, y1: 20), // '我'
              let errorTTF = QueryTTF(data: errorFontData),
              let correctTTF = QueryTTF(data: correctFontData) else {
            Issue.record("Failed to construct test TTF pairs")
            return
        }

        let encryptedText = "\u{EA01}喜欢阅读开源小说"
        let decryptedText = QueryTTF.replaceFont(
            text: encryptedText,
            errorQueryTTF: errorTTF,
            correctQueryTTF: correctTTF)

        #expect(decryptedText == "我喜欢阅读开源小说")
    }

    @Test("Test JSEngine Bridge queryTTF and replaceFont Integration")
    func jSEngineBridgeFontMethods() {
        guard let errorFontData = makeMinimalTTFData(unicodeCode: 0xEA02, x1: 15, y1: 25),
              let correctFontData = makeMinimalTTFData(unicodeCode: 0x4F60, x1: 15, y1: 25) else { // '你'
            Issue.record("Failed to construct font data")
            return
        }

        let errBase64 = errorFontData.base64EncodedString()
        let corrBase64 = correctFontData.base64EncodedString()

        let jsEngine = JSEngine()
        let script = """
        var errTTF = java.queryTTF("\(errBase64)");
        var corrTTF = java.queryTTF("\(corrBase64)");
        var rawText = "\\uEA02好，世界！";
        java.replaceFont(rawText, errTTF, corrTTF);
        """

        let result = jsEngine.evaluate(script: script)
        #expect(result == "你好，世界！")
    }

    @Test("Test AnalyzeUrl WebJs and WebView Options Parsing")
    func analyzeUrlWebViewOptions() throws {
        let rawUrl = "https://example.com/chapter/1,{" +
            "\"useWebView\": true," +
            "\"webViewDelayTime\": 1500," +
            "\"webJs\": \"console.log('loaded'); document.body.innerHTML;\"" +
            "}"

        let analyzeUrl = try AnalyzeUrl(rawUrl: rawUrl)
        #expect(analyzeUrl.url.absoluteString == "https://example.com/chapter/1")
        #expect(analyzeUrl.useWebView == true)
        #expect(analyzeUrl.webViewDelayTime == 1500)
        #expect(analyzeUrl.webJs == "console.log('loaded'); document.body.innerHTML;")
    }

    @Test("Test SourceReviewService Chapter Review Parsing")
    func sourceReviewService() async throws {
        var source = BookSource(
            bookSourceUrl: "https://biquge.example.com",
            bookSourceName: "笔趣阁测试源")
        source.ruleReview = RuleReview(
            reviewUrl: "https://biquge.example.com/reviews?bookId={{key}}",
            avatarRule: "class.user@text",
            contentRule: "class.comment_item",
            postTimeRule: "class.time@text")

        let mockHtml = """
        <html>
        <body>
            <div class="comment_item">
                <span class="user">书友9527</span>
                <span class="time">2026-10-19</span>
                <p>这章写得太精彩了，期待后续！</p>
            </div>
            <div class="comment_item">
                <span class="user">书虫老张</span>
                <span class="time">2026-10-18</span>
                <p>伏笔埋得深，给作者点赞！</p>
            </div>
        </body>
        </html>
        """

        let mockClient = MockHTTPClient()
        mockClient.register(matching: "reviews") { _, _, _ in
            mockHtml
        }

        let reviewService = SourceReviewService(httpClient: mockClient)
        let book = Book(
            bookUrl: "https://biquge.example.com/book/1",
            name: "斗破苍穹",
            author: "天蚕土豆")
        let chapter = Chapter(
            url: "https://biquge.example.com/1.html",
            title: "第一章 陨落的天才",
            bookUrl: "https://biquge.example.com/book/1",
            index: 0)

        let result = try await reviewService.fetchChapterReviews(
            book: book,
            chapter: chapter,
            source: source)

        #expect(result.reviewCount == 2)
        #expect(result.reviews.count == 2)
        #expect(result.reviews[0].author == "书友9527")
        #expect(result.reviews[1].author == "书虫老张")
    }

    // MARK: - Binary TTF Generation Helper

    private func makeMinimalTTFData(
        unicodeCode: Int = 0xEA01,
        x1: Int = 10,
        y1: Int = 20) -> Data? {
        var data = Data()

        // 1. Header (12 bytes)
        appendUInt32(&data, 0x0001_0000) // sfntVersion
        appendUInt16(&data, 5) // numTables
        appendUInt16(&data, 64) // searchRange
        appendUInt16(&data, 2) // entrySelector
        appendUInt16(&data, 16) // rangeShift

        // Table Directory (5 tables * 16 bytes = 80 bytes)
        // Offset starts after 12 + 80 = 92
        var currentOffset = 92

        // Prepare table data
        let headData = makeHeadTable()
        let maxpData = makeMaxpTable()
        let locaData = makeLocaTable()
        let cmapData = makeCmapTable(unicodeCode: unicodeCode)
        let glyfData = makeGlyfTable(x1: x1, y1: y1)

        let tables: [(tag: String, data: Data)] = [
            ("cmap", cmapData),
            ("glyf", glyfData),
            ("head", headData),
            ("loca", locaData),
            ("maxp", maxpData),
        ]

        for table in tables {
            let tagAscii = Array(table.tag.utf8)
            data.append(contentsOf: tagAscii)
            appendUInt32(&data, 0) // checkSum
            appendUInt32(&data, UInt32(currentOffset))
            appendUInt32(&data, UInt32(table.data.count))
            currentOffset += table.data.count
        }

        // Append tables content
        for table in tables {
            data.append(table.data)
        }

        return data
    }

    private func makeHeadTable() -> Data {
        var data = Data()
        appendUInt16(&data, 1) // majorVersion
        appendUInt16(&data, 0) // minorVersion
        appendUInt32(&data, 0) // fontRevision
        appendUInt32(&data, 0) // checkSumAdjustment
        appendUInt32(&data, 0x5F0F_3CF5) // magicNumber
        appendUInt16(&data, 0) // flags
        appendUInt16(&data, 1000) // unitsPerEm
        appendUInt64(&data, 0) // created
        appendUInt64(&data, 0) // modified
        appendInt16(&data, 0) // xMin
        appendInt16(&data, 0) // yMin
        appendInt16(&data, 1000) // xMax
        appendInt16(&data, 1000) // yMax
        appendUInt16(&data, 0) // macStyle
        appendUInt16(&data, 8) // lowestRecPPEM
        appendInt16(&data, 2) // fontDirectionHint
        appendInt16(&data, 0) // indexToLocFormat: 0 (short offset)
        appendInt16(&data, 0) // glyphDataFormat
        return data
    }

    private func makeMaxpTable() -> Data {
        var data = Data()
        appendUInt32(&data, 0x0001_0000) // version 1.0
        appendUInt16(&data, 2) // numGlyphs (0 and 1)
        appendUInt16(&data, 4) // maxPoints
        appendUInt16(&data, 1) // maxContours
        appendUInt16(&data, 0) // maxCompositePoints
        appendUInt16(&data, 0) // maxCompositeContours
        for _ in 0 ..< 10 {
            appendUInt16(&data, 0)
        }
        return data
    }

    private func makeLocaTable() -> Data {
        var data = Data()
        // loca count = numGlyphs + 1 = 3
        // indexToLocFormat is 0, so stored as uint16, actual offset = val * 2
        appendUInt16(&data, 0) // glyph 0 offset: 0
        appendUInt16(&data, 0) // glyph 1 offset: 0 (glyph 0 is empty)
        appendUInt16(&data, 16) // glyph 1 end offset: 32 bytes
        return data
    }

    private func makeCmapTable(unicodeCode: Int) -> Data {
        var data = Data()
        appendUInt16(&data, 0) // version
        appendUInt16(&data, 1) // numTables
        // CmapRecord
        appendUInt16(&data, 3) // platformID: Windows
        appendUInt16(&data, 1) // encodingID: Unicode BMP
        appendUInt32(&data, 12) // subtable offset from cmap start

        // Subtable format 4
        // segCount = 2 (seg 0: target unicode, seg 1: 0xFFFF)
        let segCount = 2
        let length = 16 + (segCount * 8)
        appendUInt16(&data, 4) // format
        appendUInt16(&data, UInt16(length)) // length
        appendUInt16(&data, 0) // language
        appendUInt16(&data, UInt16(segCount * 2)) // segCountX2
        appendUInt16(&data, 4) // searchRange
        appendUInt16(&data, 1) // entrySelector
        appendUInt16(&data, 0) // rangeShift

        // endCode
        appendUInt16(&data, UInt16(unicodeCode))
        appendUInt16(&data, 0xFFFF)

        appendUInt16(&data, 0) // reservedPad

        // startCode
        appendUInt16(&data, UInt16(unicodeCode))
        appendUInt16(&data, 0xFFFF)

        // idDelta (target maps to glyph 1, 0xFFFF maps to 1)
        let delta = (1 - unicodeCode) & 0xFFFF
        appendUInt16(&data, UInt16(delta))
        appendUInt16(&data, 1)

        // idRangeOffsets (0 means use idDelta)
        appendUInt16(&data, 0)
        appendUInt16(&data, 0)

        return data
    }

    private func makeGlyfTable(x1: Int, y1: Int) -> Data {
        var data = Data()
        // Glyph 1: simple glyph with 2 points
        appendInt16(&data, 1) // numberOfContours
        appendInt16(&data, 0) // xMin
        appendInt16(&data, 0) // yMin
        appendInt16(&data, 100) // xMax
        appendInt16(&data, 100) // yMax

        // endPtsOfContours
        appendUInt16(&data, 1) // 2 points (index 0 and 1)
        appendUInt16(&data, 0) // instructionLength

        // flags for 2 points (0x12: uint8 positive, 0x12: uint8 positive)
        data.append(0x12)
        data.append(0x12)

        // x coordinates
        data.append(UInt8(x1 & 0xFF))
        data.append(UInt8((x1 + 10) & 0xFF))

        // y coordinates
        data.append(UInt8(y1 & 0xFF))
        data.append(UInt8((y1 + 10) & 0xFF))

        // Pad to even length
        if data.count % 2 != 0 {
            data.append(0)
        }
        return data
    }

    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var big = value.bigEndian
        data.append(Data(bytes: &big, count: 2))
    }

    private func appendInt16(_ data: inout Data, _ value: Int16) {
        var big = value.bigEndian
        data.append(Data(bytes: &big, count: 2))
    }

    private func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var big = value.bigEndian
        data.append(Data(bytes: &big, count: 4))
    }

    private func appendUInt64(_ data: inout Data, _ value: UInt64) {
        var big = value.bigEndian
        data.append(Data(bytes: &big, count: 8))
    }
}
