import CryptoKit
import Foundation
import JavaScriptCore

@objc public protocol QueryTTFJSExport: JSExport {
    func getGlyfById(_ glyfId: Int) -> String?
    func getGlyfByUnicode(_ unicode: Int) -> String?
    func getUnicodeByGlyf(_ glyph: String) -> Int
    func getGlyfIdByUnicode(_ unicode: Int) -> Int
    func isBlankUnicode(_ unicode: Int) -> Bool
    var unicodeToGlyphMap: [NSNumber: String] { get }
    var glyphToUnicodeMap: [String: NSNumber] { get }
    var unicodeToGlyphIdMap: [NSNumber: NSNumber] { get }
}

/// TTF / OpenType 字体文件解析与字符混淆还原引擎
/// 对标 Android Legado: `io.legado.app.model.analyzeRule.QueryTTF.java`
@objc public final class QueryTTF: NSObject, QueryTTFJSExport {
    struct Header {
        var sfntVersion: UInt32 = 0
        var numTables = 0
        var searchRange = 0
        var entrySelector = 0
        var rangeShift = 0
    }

    struct Directory {
        var tableTag = ""
        var checkSum: UInt32 = 0
        var offset = 0
        var length = 0
    }

    struct HeadLayout {
        var majorVersion = 0
        var minorVersion = 0
        var fontRevision: UInt32 = 0
        var checkSumAdjustment: UInt32 = 0
        var magicNumber: UInt32 = 0
        var flags = 0
        var unitsPerEm = 0
        var created: UInt64 = 0
        var modified: UInt64 = 0
        var xMin: Int16 = 0
        var yMin: Int16 = 0
        var xMax: Int16 = 0
        var yMax: Int16 = 0
        var macStyle = 0
        var lowestRecPPEM = 0
        var fontDirectionHint: Int16 = 0
        var indexToLocFormat: Int16 = 0
        var glyphDataFormat: Int16 = 0
    }

    struct MaxpLayout {
        var version: UInt32 = 0
        var numGlyphs = 0
        var maxPoints = 0
        var maxContours = 0
        var maxCompositePoints = 0
        var maxCompositeContours = 0
    }

    struct CmapRecord {
        var platformID = 0
        var encodingID = 0
        var offset = 0
    }

    struct GlyphSimple {
        var endPtsOfContours: [Int] = []
        var instructionLength = 0
        var instructions: [Int] = []
        var flags: [Int] = []
        var xCoordinates: [Int] = []
        var yCoordinates: [Int] = []
    }

    struct GlyphComponent {
        var flags = 0
        var glyphIndex = 0
        var argument1 = 0
        var argument2 = 0
        var xScale: Float = 1.0
        var scale01: Float = 0.0
        var scale10: Float = 0.0
        var yScale: Float = 1.0
    }

    final class GlyfLayout {
        var numberOfContours: Int16 = 0
        var xMin: Int16 = 0
        var yMin: Int16 = 0
        var xMax: Int16 = 0
        var yMax: Int16 = 0
        var glyphSimple: GlyphSimple?
        var glyphComponent: [GlyphComponent] = []
    }

    final class BufferReader {
        private let data: Data
        private(set) var offset: Int

        init(data: Data, offset: Int = 0) {
            self.data = data
            self.offset = offset
        }

        func position(_ newOffset: Int) {
            offset = max(0, min(newOffset, data.count))
        }

        var isEOF: Bool {
            offset >= data.count
        }

        func readUInt64() -> UInt64 {
            guard offset + 8 <= data.count else { offset = data.count; return 0 }
            let val = data.withUnsafeBytes { ptr -> UInt64 in
                ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self)
            }
            offset += 8
            return UInt64(bigEndian: val)
        }

        func readUInt32() -> UInt32 {
            guard offset + 4 <= data.count else { offset = data.count; return 0 }
            let val = data.withUnsafeBytes { ptr -> UInt32 in
                ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            }
            offset += 4
            return UInt32(bigEndian: val)
        }

        func readInt32() -> Int32 {
            Int32(bitPattern: readUInt32())
        }

        func readUInt16() -> UInt16 {
            guard offset + 2 <= data.count else { offset = data.count; return 0 }
            let val = data.withUnsafeBytes { ptr -> UInt16 in
                ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
            }
            offset += 2
            return UInt16(bigEndian: val)
        }

        func readInt16() -> Int16 {
            Int16(bitPattern: readUInt16())
        }

        func readUInt8() -> UInt8 {
            guard offset < data.count else { return 0 }
            let byteVal = data[offset]
            offset += 1
            return byteVal
        }

        func readInt8() -> Int8 {
            Int8(bitPattern: readUInt8())
        }

        func readByteArray(_ len: Int) -> Data {
            guard len > 0 else { return Data() }
            let end = min(offset + len, data.count)
            let sub = data.subdata(in: offset ..< end)
            offset = end
            return sub
        }

        func readUInt8Array(_ len: Int) -> [Int] {
            guard len > 0 else { return [] }
            var arr: [Int] = []
            arr.reserveCapacity(len)
            for _ in 0 ..< len {
                arr.append(Int(readUInt8()))
            }
            return arr
        }

        func readUInt16Array(_ len: Int) -> [Int] {
            guard len > 0 else { return [] }
            var arr: [Int] = []
            arr.reserveCapacity(len)
            for _ in 0 ..< len {
                arr.append(Int(readUInt16()))
            }
            return arr
        }

        func readInt16Array(_ len: Int) -> [Int] {
            guard len > 0 else { return [] }
            var arr: [Int] = []
            arr.reserveCapacity(len)
            for _ in 0 ..< len {
                arr.append(Int(readInt16()))
            }
            return arr
        }

        func readInt32Array(_ len: Int) -> [Int] {
            guard len > 0 else { return [] }
            var arr: [Int] = []
            arr.reserveCapacity(len)
            for _ in 0 ..< len {
                arr.append(Int(readInt32()))
            }
            return arr
        }
    }

    public var unicodeToGlyph: [Int: String] = [:]
    public var glyphToUnicode: [String: Int] = [:]
    public var unicodeToGlyphId: [Int: Int] = [:]

    public var unicodeToGlyphMap: [NSNumber: String] {
        var dict: [NSNumber: String] = [:]
        for (unicodeKey, glyphVal) in unicodeToGlyph {
            dict[NSNumber(value: unicodeKey)] = glyphVal
        }
        return dict
    }

    public var glyphToUnicodeMap: [String: NSNumber] {
        var dict: [String: NSNumber] = [:]
        for (glyphVal, unicodeKey) in glyphToUnicode {
            dict[glyphVal] = NSNumber(value: unicodeKey)
        }
        return dict
    }

    public var unicodeToGlyphIdMap: [NSNumber: NSNumber] {
        var dict: [NSNumber: NSNumber] = [:]
        for (unicodeKey, glyphIdVal) in unicodeToGlyphId {
            dict[NSNumber(value: unicodeKey)] = NSNumber(value: glyphIdVal)
        }
        return dict
    }

    var fileHeader = Header()
    var directories: [String: Directory] = [:]
    var head = HeadLayout()
    var maxp = MaxpLayout()
    var loca: [Int] = []
    var glyfArray: [GlyfLayout?] = []

    public init?(data: Data) {
        super.init()
        guard data.count >= 12 else { return nil }
        parseFont(data: data)
    }

    public convenience init?(base64String: String) {
        var clean = base64String.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commaIndex = clean.firstIndex(of: ",") {
            clean = String(clean[clean.index(after: commaIndex)...])
        }
        guard let data = Data(base64Encoded: clean, options: .ignoreUnknownCharacters) else {
            return nil
        }
        self.init(data: data)
    }

    public func getGlyfById(_ glyfId: Int) -> String? {
        guard glyfId >= 0, glyfId < glyfArray.count, let glyph = glyfArray[glyfId] else {
            return nil
        }
        if glyph.numberOfContours >= 0 {
            guard let simple = glyph.glyphSimple else { return nil }
            let count = simple.flags.count
            var coords: [String] = []
            coords.reserveCapacity(count)
            for idx in 0 ..< count {
                let coordX = idx < simple.xCoordinates.count ? simple.xCoordinates[idx] : 0
                let coordY = idx < simple.yCoordinates.count ? simple.yCoordinates[idx] : 0
                coords.append("\(coordX),\(coordY)")
            }
            return coords.joined(separator: "|")
        } else {
            let list = glyph.glyphComponent.map { component in
                "{flags:\(component.flags),glyphIndex:\(component.glyphIndex)," +
                    "arg1:\(component.argument1),arg2:\(component.argument2)," +
                    "xScale:\(component.xScale),scale01:\(component.scale01)," +
                    "scale10:\(component.scale10),yScale:\(component.yScale)}"
            }
            return "[" + list.joined(separator: ",") + "]"
        }
    }

    public func getGlyfIdByUnicode(_ unicode: Int) -> Int {
        unicodeToGlyphId[unicode] ?? 0
    }

    public func getGlyfByUnicode(_ unicode: Int) -> String? {
        unicodeToGlyph[unicode]
    }

    public func getUnicodeByGlyf(_ glyph: String) -> Int {
        glyphToUnicode[glyph] ?? 0
    }

    public func isBlankUnicode(_ unicode: Int) -> Bool {
        switch unicode {
        case 0x0009, 0x0020, 0x00A0, 0x2002, 0x2003, 0x2007,
             0x200A, 0x200B, 0x200C, 0x200D, 0x202F, 0x205F:
            return true

        default:
            return false
        }
    }

    public static func replaceFont(
        text: String,
        errorQueryTTF: QueryTTF?,
        correctQueryTTF: QueryTTF?,
        filter: Bool = false) -> String {
        guard let errorQueryTTF, let correctQueryTTF else { return text }

        var result = ""
        for char in text {
            guard let scalar = char.unicodeScalars.first else { continue }
            let oldCode = Int(scalar.value)

            if errorQueryTTF.isBlankUnicode(oldCode) {
                result.append(char)
                continue
            }

            var glyf = errorQueryTTF.getGlyfByUnicode(oldCode)
            if errorQueryTTF.getGlyfIdByUnicode(oldCode) == 0 {
                glyf = nil
            }

            if filter, glyf == nil {
                continue
            }

            if let glyf {
                let code = correctQueryTTF.getUnicodeByGlyf(glyf)
                if code != 0, let newScalar = UnicodeScalar(code) {
                    result.append(Character(newScalar))
                    continue
                }
            }
            result.append(char)
        }
        return result
    }
}

public final class QueryTTFCache: @unchecked Sendable {
    public static let shared = QueryTTFCache()
    private let lock = NSLock()
    private var cache: [String: QueryTTF] = [:]

    private init() {}

    public func get(key: String) -> QueryTTF? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    public func put(key: String, ttf: QueryTTF) {
        lock.lock()
        defer { lock.unlock() }
        if cache.count > 16 {
            cache.removeAll()
        }
        cache[key] = ttf
    }

    public static func cacheKey(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
