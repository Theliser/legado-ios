import CommonCrypto
import Foundation
import JavaScriptCore

extension JSEngine {
    func createSymmetricCryptoObject(
        transformation: String,
        keyData: Data,
        ivData: Data?) -> JSValue? {
        guard let cryptoObj = JSValue(newObjectIn: context) else { return nil }
        let isDES = transformation.uppercased().contains("DES")
        let isECB = transformation.uppercased().contains("ECB") || ivData == nil
        let algo: CCAlgorithm = isDES ? CCAlgorithm(kCCAlgorithmDES) : CCAlgorithm(kCCAlgorithmAES)
        let blockSize = isDES ? kCCBlockSizeDES : kCCBlockSizeAES128
        let options: CCOptions = isECB
            ? CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode)
            : CCOptions(kCCOptionPKCS7Padding)

        let decryptStr: @convention(block) (String) -> String = { dataStr in
            let rawData = Data(base64Encoded: dataStr) ?? Data(dataStr.utf8)
            guard let result = Self.runCipher(
                params: CipherParams(
                    operation: CCOperation(kCCDecrypt),
                    algorithm: algo,
                    options: options,
                    blockSize: blockSize),
                keyData: keyData,
                ivData: ivData,
                inputData: rawData) else { return "" }
            return String(data: result, encoding: .utf8) ?? ""
        }

        let encryptBase64: @convention(block) (String) -> String = { dataStr in
            guard let result = Self.runCipher(
                params: CipherParams(
                    operation: CCOperation(kCCEncrypt),
                    algorithm: algo,
                    options: options,
                    blockSize: blockSize),
                keyData: keyData,
                ivData: ivData,
                inputData: Data(dataStr.utf8)) else { return "" }
            return result.base64EncodedString()
        }

        cryptoObj.setObject(decryptStr, forKeyedSubscript: "decryptStr" as NSString)
        cryptoObj.setObject(decryptStr, forKeyedSubscript: "decrypt" as NSString)
        cryptoObj.setObject(encryptBase64, forKeyedSubscript: "encryptBase64" as NSString)
        return cryptoObj
    }

    private struct CipherParams {
        let operation: CCOperation
        let algorithm: CCAlgorithm
        let options: CCOptions
        let blockSize: Int
    }

    private static func runCipher(
        params: CipherParams,
        keyData: Data,
        ivData: Data?,
        inputData: Data) -> Data? {
        let bufferSize = inputData.count + params.blockSize
        var buffer = Data(count: bufferSize)
        var numBytes: size_t = 0
        let status = buffer.withUnsafeMutableBytes { bPtr in
            inputData.withUnsafeBytes { dPtr in
                keyData.withUnsafeBytes { kPtr in
                    CCCrypt(
                        params.operation,
                        params.algorithm,
                        params.options,
                        kPtr.baseAddress,
                        keyData.count,
                        ivData?.withUnsafeBytes { $0.baseAddress },
                        dPtr.baseAddress,
                        inputData.count,
                        bPtr.baseAddress,
                        bufferSize,
                        &numBytes)
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return buffer.prefix(numBytes)
    }

    static func toNumChapter(_ title: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(第)(.+?)(章)"#),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let rangeAll = Range(match.range(at: 0), in: title),
              let range1 = Range(match.range(at: 1), in: title),
              let range2 = Range(match.range(at: 2), in: title),
              let range3 = Range(match.range(at: 3), in: title) else {
            return title
        }
        let middle = String(title[range2]).trimmingCharacters(in: .whitespaces)
        let replacement: String
        if let num = Int(middle) {
            replacement = "\(title[range1])\(num)\(title[range3])"
        } else {
            let parsed = parseChineseNumber(middle)
            if parsed > 0 {
                replacement = "\(title[range1])\(parsed)\(title[range3])"
            } else {
                return title
            }
        }
        var updated = title
        updated.replaceSubrange(rangeAll, with: replacement)
        return updated
    }

    private static func parseChineseNumber(_ str: String) -> Int {
        let charMap: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9,
        ]
        let unitMap: [Character: Int] = [
            "十": 10, "百": 100, "千": 1000, "万": 10000, "亿": 100_000_000,
        ]
        var total = 0
        var current = 0
        var section = 0
        for char in str {
            if let digit = charMap[char] {
                current = digit
            } else if let unit = unitMap[char] {
                if unit == 10000 || unit == 100_000_000 {
                    section = (section + (current == 0 ? 1 : current)) * unit
                    total += section
                    section = 0
                    current = 0
                } else {
                    let factor = current == 0 ? 1 : current
                    section += factor * unit
                    current = 0
                }
            }
        }
        return total + section + current
    }
}
