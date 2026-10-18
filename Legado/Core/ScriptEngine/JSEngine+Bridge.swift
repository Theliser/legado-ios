import CommonCrypto
import CryptoKit
import Foundation
import JavaScriptCore

struct SyncHTTPResponse {
    let body: String
    let headers: [String: String]
    let cookies: [String: String]
}

extension JSEngine {
    func setupBridges() {
        setupJavaBridge()
        setupCookieBridge()
    }

    private func setupJavaBridge() {
        guard let javaObj = JSValue(newObjectIn: context) else { return }
        setupJavaNetworkMethods(on: javaObj)
        setupJavaStorageMethods(on: javaObj)
        setupJavaDOMMethods(on: javaObj)
        setupChineseAndEncodingMethods(on: javaObj)
        setupBase64AndHexMethods(on: javaObj)
        setupHashingMethods(on: javaObj)
        setupHMacMethods(on: javaObj)
        setupTimeAndCryptoMethods(on: javaObj)
        context.setObject(javaObj, forKeyedSubscript: "java" as NSString)
    }

    private func setupJavaNetworkMethods(on javaObj: JSValue) {
        let ajax: @convention(block) (String) -> String = { urlString in
            guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return "" }
            return Self.syncRequest(url: url).body
        }
        javaObj.setObject(ajax, forKeyedSubscript: "ajax" as NSString)
        context.setObject(ajax, forKeyedSubscript: "ajax" as NSString)

        let get: @convention(block) (String, JSValue?) -> JSValue = { [weak self] urlString, headersVal in
            guard let self, let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return JSValue(newObjectIn: self?.context)
            }
            let headers = (headersVal?.toObject() as? [String: String]) ?? [:]
            let res = Self.syncRequest(url: url, method: "GET", headers: headers)
            return self.wrapResponse(res)
        }
        javaObj.setObject(get, forKeyedSubscript: "get" as NSString)
        javaObj.setObject(get, forKeyedSubscript: "connect" as NSString)
        javaObj.setObject(get, forKeyedSubscript: "head" as NSString)

        let post: @convention(block) (String, String, JSValue?) -> JSValue = { [weak self] urlStr, body, headersVal in
            guard let self, let url = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return JSValue(newObjectIn: self?.context)
            }
            let headers = (headersVal?.toObject() as? [String: String]) ?? [:]
            let res = Self.syncRequest(url: url, method: "POST", body: body.data(using: .utf8), headers: headers)
            return self.wrapResponse(res)
        }
        javaObj.setObject(post, forKeyedSubscript: "post" as NSString)
    }

    private func setupJavaStorageMethods(on javaObj: JSValue) {
        let putVal: @convention(block) (String, String) -> Void = { [weak self] key, val in
            self?.memoryStorage[key] = val
        }
        let getVal: @convention(block) (String) -> String = { [weak self] key in
            self?.memoryStorage[key] ?? ""
        }
        javaObj.setObject(putVal, forKeyedSubscript: "put" as NSString)
        javaObj.setObject(getVal, forKeyedSubscript: "get" as NSString)
    }

    private func setupJavaDOMMethods(on javaObj: JSValue) {
        let setContent: @convention(block) (JSValue) -> Void = { [weak self] val in
            if val.isString {
                self?.currentContent = val.toString()
            } else if val.isObject {
                let json = self?.context.objectForKeyedSubscript("JSON" as NSString)
                let stringify = json?.objectForKeyedSubscript("stringify" as NSString)
                if let str = stringify?.call(withArguments: [val])?.toString() {
                    self?.currentContent = str
                } else {
                    self?.currentContent = val.toString()
                }
            } else {
                self?.currentContent = val.toString()
            }
        }
        let getString: @convention(block) (String) -> String = { [weak self] rule in
            guard let self else { return "" }
            if let stored = self.memoryStorage[rule] {
                return stored
            }
            if rule.hasPrefix("$.") || rule.hasPrefix("@Json:") {
                return JSONPathParser.parse(json: self.currentContent, path: rule).first ?? ""
            } else {
                return CSSSelectorParser.parseElements(
                    html: self.currentContent,
                    rule: rule,
                    baseUrl: self.currentBaseUrl).first ?? ""
            }
        }
        let getElements: @convention(block) (String) -> [String] = { [weak self] rule in
            guard let self else { return [] }
            if rule.hasPrefix("$.") || rule.hasPrefix("@Json:") {
                return JSONPathParser.parse(json: self.currentContent, path: rule)
            } else {
                return CSSSelectorParser.parseElements(
                    html: self.currentContent,
                    rule: rule,
                    baseUrl: self.currentBaseUrl)
            }
        }
        javaObj.setObject(setContent, forKeyedSubscript: "setContent" as NSString)
        javaObj.setObject(getString, forKeyedSubscript: "getString" as NSString)
        javaObj.setObject(getString, forKeyedSubscript: "getElement" as NSString)
        javaObj.setObject(getElements, forKeyedSubscript: "getElements" as NSString)
        javaObj.setObject(getElements, forKeyedSubscript: "getStringList" as NSString)
    }

    private func setupChineseAndEncodingMethods(on javaObj: JSValue) {
        let t2s: @convention(block) (String) -> String = { input in
            input.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? input
        }
        let s2t: @convention(block) (String) -> String = { input in
            input.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? input
        }
        let encodeURI: @convention(block) (String) -> String = { input in
            input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        }
        let toNumChapterFunc: @convention(block) (String) -> String = { input in
            Self.toNumChapter(input)
        }
        let htmlFormatFunc: @convention(block) (String) -> String = { input in
            input
                .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
                .replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
                .replacingOccurrences(of: "<p[^>]*>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        javaObj.setObject(t2s, forKeyedSubscript: "t2s" as NSString)
        javaObj.setObject(s2t, forKeyedSubscript: "s2t" as NSString)
        javaObj.setObject(encodeURI, forKeyedSubscript: "encodeURI" as NSString)
        javaObj.setObject(toNumChapterFunc, forKeyedSubscript: "toNumChapter" as NSString)
        javaObj.setObject(htmlFormatFunc, forKeyedSubscript: "htmlFormat" as NSString)

        context.setObject(t2s, forKeyedSubscript: "t2s" as NSString)
        context.setObject(s2t, forKeyedSubscript: "s2t" as NSString)
        context.setObject(encodeURI, forKeyedSubscript: "encodeURI" as NSString)
    }

    private func setupBase64AndHexMethods(on javaObj: JSValue) {
        let base64Encode: @convention(block) (String) -> String = { input in
            Data(input.utf8).base64EncodedString()
        }
        let base64Decode: @convention(block) (String) -> String = { input in
            guard let data = Data(base64Encoded: input) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        let base64DecodeToByteArray: @convention(block) (String) -> [UInt8] = { input in
            guard let data = Data(base64Encoded: input) else { return [] }
            return [UInt8](data)
        }
        let hexDecodeToString: @convention(block) (String) -> String = { hex in
            var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanHex.count % 2 != 0 {
                cleanHex = "0" + cleanHex
            }
            var data = Data()
            var index = cleanHex.startIndex
            while index < cleanHex.endIndex {
                let next = cleanHex.index(index, offsetBy: 2)
                if let byte = UInt8(cleanHex[index ..< next], radix: 16) {
                    data.append(byte)
                }
                index = next
            }
            return String(data: data, encoding: .utf8) ?? ""
        }

        javaObj.setObject(base64Encode, forKeyedSubscript: "base64Encode" as NSString)
        javaObj.setObject(base64Decode, forKeyedSubscript: "base64Decode" as NSString)
        javaObj.setObject(base64DecodeToByteArray, forKeyedSubscript: "base64DecodeToByteArray" as NSString)
        javaObj.setObject(hexDecodeToString, forKeyedSubscript: "hexDecodeToString" as NSString)
    }

    private func setupHashingMethods(on javaObj: JSValue) {
        let md5Encode: @convention(block) (String) -> String = { input in
            let digest = Insecure.MD5.hash(data: Data(input.utf8))
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }
        let md5Encode16: @convention(block) (String) -> String = { input in
            let digest = Insecure.MD5.hash(data: Data(input.utf8))
            let full = digest.map { String(format: "%02hhx", $0) }.joined()
            if full.count >= 24 {
                let start = full.index(full.startIndex, offsetBy: 8)
                let end = full.index(full.startIndex, offsetBy: 24)
                return String(full[start ..< end])
            }
            return full
        }
        let digestHex: @convention(block) (String, String) -> String = { dataStr, algo in
            let upper = algo.uppercased()
            let rawData = Data(dataStr.utf8)
            if upper.contains("256") {
                return SHA256.hash(data: rawData).map { String(format: "%02x", $0) }.joined()
            } else if upper.contains("512") {
                return SHA512.hash(data: rawData).map { String(format: "%02x", $0) }.joined()
            } else if upper.contains("SHA") || upper.contains("1") {
                return Insecure.SHA1.hash(data: rawData).map { String(format: "%02x", $0) }.joined()
            } else {
                return Insecure.MD5.hash(data: rawData).map { String(format: "%02x", $0) }.joined()
            }
        }
        let digestBase64Str: @convention(block) (String, String) -> String = { dataStr, algo in
            let upper = algo.uppercased()
            let rawData = Data(dataStr.utf8)
            if upper.contains("256") {
                return Data(SHA256.hash(data: rawData)).base64EncodedString()
            } else if upper.contains("SHA") || upper.contains("1") {
                return Data(Insecure.SHA1.hash(data: rawData)).base64EncodedString()
            } else {
                return Data(Insecure.MD5.hash(data: rawData)).base64EncodedString()
            }
        }
        javaObj.setObject(md5Encode, forKeyedSubscript: "md5Encode" as NSString)
        javaObj.setObject(md5Encode16, forKeyedSubscript: "md5Encode16" as NSString)
        javaObj.setObject(digestHex, forKeyedSubscript: "digestHex" as NSString)
        javaObj.setObject(digestBase64Str, forKeyedSubscript: "digestBase64Str" as NSString)
    }

    private func setupHMacMethods(on javaObj: JSValue) {
        let hmacHex: @convention(block) (String, String, String) -> String = { dataStr, algo, keyStr in
            let keyData = SymmetricKey(data: Data(keyStr.utf8))
            let msgData = Data(dataStr.utf8)
            if algo.uppercased().contains("1") {
                let mac = HMAC<Insecure.SHA1>.authenticationCode(for: msgData, using: keyData)
                return mac.map { String(format: "%02x", $0) }.joined()
            } else {
                let mac = HMAC<SHA256>.authenticationCode(for: msgData, using: keyData)
                return mac.map { String(format: "%02x", $0) }.joined()
            }
        }
        let hmacBase64: @convention(block) (String, String, String) -> String = { dataStr, algo, keyStr in
            let keyData = SymmetricKey(data: Data(keyStr.utf8))
            let msgData = Data(dataStr.utf8)
            if algo.uppercased().contains("1") {
                let mac = HMAC<Insecure.SHA1>.authenticationCode(for: msgData, using: keyData)
                return Data(mac).base64EncodedString()
            } else {
                let mac = HMAC<SHA256>.authenticationCode(for: msgData, using: keyData)
                return Data(mac).base64EncodedString()
            }
        }

        javaObj.setObject(hmacHex, forKeyedSubscript: "HMacHex" as NSString)
        javaObj.setObject(hmacBase64, forKeyedSubscript: "HMacBase64" as NSString)
    }

    private func setupTimeAndCryptoMethods(on javaObj: JSValue) {
        let timeFormat: @convention(block) (Double) -> String = { timestamp in
            let date = Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        }
        let timeFormatUTC: @convention(block) (Double, String, Int) -> String = { timestamp, formatStr, hourOffset in
            let date = Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = formatStr.isEmpty ? "yyyy-MM-dd HH:mm:ss" : formatStr
            formatter.timeZone = TimeZone(secondsFromGMT: hourOffset * 3600)
            return formatter.string(from: date)
        }
        let randomUUID: @convention(block) () -> String = {
            UUID().uuidString
        }
        let createCrypto: @convention(block) (String, String, JSValue?) -> JSValue? = { [weak self] trans, key, ivVal in
            guard let self else { return nil }
            let ivStr = ivVal?.isString == true ? ivVal?.toString() : nil
            return self.createSymmetricCryptoObject(
                transformation: trans,
                keyData: Data(key.utf8),
                ivData: ivStr != nil ? Data(ivStr!.utf8) : nil)
        }
        typealias AESDecodeBlock = @convention(block) (String, String, String, String) -> String
        let aesDecode: AESDecodeBlock = { [weak self] dStr, kStr, trStr, ivStr in
            guard let self,
                  let crypto = self.createSymmetricCryptoObject(
                      transformation: trStr,
                      keyData: Data(kStr.utf8),
                      ivData: Data(ivStr.utf8)),
                  let decryptFunc = crypto.objectForKeyedSubscript("decryptStr" as NSString) else {
                return ""
            }
            return decryptFunc.call(withArguments: [dStr])?.toString() ?? ""
        }
        let androidId: @convention(block) () -> String = { "legado_ios_device" }
        let log: @convention(block) (String) -> Void = { _ in }

        javaObj.setObject(timeFormat, forKeyedSubscript: "timeFormat" as NSString)
        javaObj.setObject(timeFormatUTC, forKeyedSubscript: "timeFormatUTC" as NSString)
        javaObj.setObject(randomUUID, forKeyedSubscript: "randomUUID" as NSString)
        javaObj.setObject(createCrypto, forKeyedSubscript: "createSymmetricCrypto" as NSString)
        javaObj.setObject(aesDecode, forKeyedSubscript: "aesBase64DecodeToString" as NSString)
        javaObj.setObject(androidId, forKeyedSubscript: "androidId" as NSString)
        javaObj.setObject(log, forKeyedSubscript: "toast" as NSString)
        javaObj.setObject(log, forKeyedSubscript: "longToast" as NSString)
        javaObj.setObject(log, forKeyedSubscript: "log" as NSString)
    }

    private func setupCookieBridge() {
        guard let cookieObj = JSValue(newObjectIn: context) else { return }
        let removeCookie: @convention(block) (String) -> Void = { _ in }
        let getCookie: @convention(block) (String) -> String = { _ in "" }
        cookieObj.setObject(removeCookie, forKeyedSubscript: "removeCookie" as NSString)
        cookieObj.setObject(getCookie, forKeyedSubscript: "getCookie" as NSString)
        context.setObject(cookieObj, forKeyedSubscript: "cookie" as NSString)
    }

    private func wrapResponse(_ res: SyncHTTPResponse) -> JSValue {
        guard let respObj = JSValue(newObjectIn: context) else {
            return JSValue(undefinedIn: context)
        }
        let bodyFunc: @convention(block) () -> String = { res.body }
        let headerFunc: @convention(block) (String) -> String = { key in
            res.headers[key] ?? res.headers[key.lowercased()] ?? ""
        }
        let cookieFunc: @convention(block) (String) -> String = { key in
            res.cookies[key] ?? ""
        }
        respObj.setObject(bodyFunc, forKeyedSubscript: "body" as NSString)
        respObj.setObject(headerFunc, forKeyedSubscript: "header" as NSString)
        respObj.setObject(cookieFunc, forKeyedSubscript: "cookie" as NSString)
        return respObj
    }

    static func syncRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]) -> SyncHTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 8.0
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (key, val) in headers {
            request.setValue(val, forHTTPHeaderField: key)
        }

        var resultData: Data?
        var httpResponse: HTTPURLResponse?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            resultData = data
            httpResponse = response as? HTTPURLResponse
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 8.0)

        var headerDict: [String: String] = [:]
        var cookieDict: [String: String] = [:]
        if let httpResponse {
            for (headerKey, headerVal) in httpResponse.allHeaderFields {
                headerDict[String(describing: headerKey)] = String(describing: headerVal)
            }
            if let stringHeaders = httpResponse.allHeaderFields as? [String: String] {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: stringHeaders, for: url)
                for cookie in cookies {
                    cookieDict[cookie.name] = cookie.value
                }
            }
        }

        guard let data = resultData else {
            return SyncHTTPResponse(body: "", headers: headerDict, cookies: cookieDict)
        }
        let bodyStr = CharsetDetector.decode(data: data, response: httpResponse)
        return SyncHTTPResponse(body: bodyStr, headers: headerDict, cookies: cookieDict)
    }
}
