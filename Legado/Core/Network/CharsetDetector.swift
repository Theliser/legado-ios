import CoreFoundation
import Foundation

/// 字符集检测与解码器，用于中文小说网站常见编码（GBK / GB2312 / GB18030 / Big5 / UTF-8）
public enum CharsetDetector {
    /// GB18030 编码（向下兼容 GBK 和 GB2312）
    public static let gbkEncoding: String.Encoding = {
        let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }()

    /// Big5 繁体中文编码
    public static let big5Encoding: String.Encoding = {
        let cfEncoding = CFStringEncoding(CFStringEncodings.big5.rawValue)
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }()

    /// 自动根据 HTTP 响应头、HTML Meta 标签及二进制内容检测并解码
    public static func decode(data: Data, response: HTTPURLResponse? = nil) -> String {
        // 1. 优先读取 HTTP Header 声明的 charset
        if let response,
           let textEncodingName = response.textEncodingName?.lowercased() {
            if let encoding = stringEncoding(from: textEncodingName),
               let decoded = String(data: data, encoding: encoding) {
                return decoded
            }
        }

        // 2. 尝试从前 1024 字节嗅探 HTML <meta charset="...">
        let prefixLength = min(data.count, 1024)
        let prefixData = data.prefix(prefixLength)
        if let asciiPrefix = String(data: prefixData, encoding: .ascii)?.lowercased() {
            if asciiPrefix.contains("charset=gbk") || asciiPrefix.contains("charset=\"gbk\"") ||
                asciiPrefix.contains("charset=gb2312") || asciiPrefix.contains("charset=\"gb2312\"") ||
                asciiPrefix.contains("charset=gb18030") || asciiPrefix.contains("charset=\"gb18030\"") {
                if let decoded = String(data: data, encoding: gbkEncoding) {
                    return decoded
                }
            } else if asciiPrefix.contains("charset=big5") || asciiPrefix.contains("charset=\"big5\"") {
                if let decoded = String(data: data, encoding: big5Encoding) {
                    return decoded
                }
            }
        }

        // 3. 默认优先尝试 UTF-8
        if let utf8String = String(data: data, encoding: .utf8) {
            return utf8String
        }

        // 4. UTF-8 失败则尝试 GBK
        if let gbkString = String(data: data, encoding: gbkEncoding) {
            return gbkString
        }

        // 5. 尝试 Big5
        if let big5String = String(data: data, encoding: big5Encoding) {
            return big5String
        }

        // 6. 保底 ISO Latin 1 (无损保留单字节)
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    /// 根据编码名称字符串获取 String.Encoding
    public static func stringEncoding(from charsetName: String) -> String.Encoding? {
        let cleaned = charsetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch cleaned {
        case "utf-8", "utf8":
            return .utf8

        case "gbk", "gb2312", "gb18030":
            return gbkEncoding

        case "big5", "big-5":
            return big5Encoding

        default:
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(cleaned as CFString)
            guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        }
    }
}
