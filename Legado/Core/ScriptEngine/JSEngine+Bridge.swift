import CryptoKit
import Foundation
import JavaScriptCore

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
        setupEncodingMethods(on: javaObj)
        context.setObject(javaObj, forKeyedSubscript: "java" as NSString)
    }

    private func setupJavaNetworkMethods(on javaObj: JSValue) {
        let ajax: @convention(block) (String) -> String = { urlString in
            guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return "" }
            return Self.syncRequest(url: url)
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
        let getElement: @convention(block) (String) -> String = { [weak self] rule in
            guard let self else { return "" }
            if rule.hasPrefix("$.") || rule.hasPrefix("@Json:") {
                return JSONPathParser.parse(json: self.currentContent, path: rule).first ?? ""
            } else {
                return CSSSelectorParser.parseElements(
                    html: self.currentContent,
                    rule: rule,
                    baseUrl: self.currentBaseUrl).first ?? ""
            }
        }
        javaObj.setObject(setContent, forKeyedSubscript: "setContent" as NSString)
        javaObj.setObject(getString, forKeyedSubscript: "getString" as NSString)
        javaObj.setObject(getElement, forKeyedSubscript: "getElement" as NSString)
        javaObj.setObject(getElements, forKeyedSubscript: "getElements" as NSString)
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
        javaObj.setObject(t2s, forKeyedSubscript: "t2s" as NSString)
        javaObj.setObject(s2t, forKeyedSubscript: "s2t" as NSString)
        javaObj.setObject(encodeURI, forKeyedSubscript: "encodeURI" as NSString)
        context.setObject(t2s, forKeyedSubscript: "t2s" as NSString)
        context.setObject(s2t, forKeyedSubscript: "s2t" as NSString)
        context.setObject(encodeURI, forKeyedSubscript: "encodeURI" as NSString)
    }

    private func setupEncodingMethods(on javaObj: JSValue) {
        let base64Encode: @convention(block) (String) -> String = { input in
            Data(input.utf8).base64EncodedString()
        }
        let base64Decode: @convention(block) (String) -> String = { input in
            guard let data = Data(base64Encoded: input) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
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
        let md5Encode: @convention(block) (String) -> String = { input in
            let digest = Insecure.MD5.hash(data: Data(input.utf8))
            return digest.map { String(format: "%02hhx", $0) }.joined()
        }
        let timeFormat: @convention(block) (Double) -> String = { timestamp in
            let date = Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1000 : timestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        }
        let androidId: @convention(block) () -> String = { "legado_ios_device" }
        let log: @convention(block) (String) -> Void = { _ in }

        javaObj.setObject(base64Encode, forKeyedSubscript: "base64Encode" as NSString)
        javaObj.setObject(base64Decode, forKeyedSubscript: "base64Decode" as NSString)
        javaObj.setObject(hexDecodeToString, forKeyedSubscript: "hexDecodeToString" as NSString)
        javaObj.setObject(md5Encode, forKeyedSubscript: "md5Encode" as NSString)
        javaObj.setObject(timeFormat, forKeyedSubscript: "timeFormat" as NSString)
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

    private func wrapResponse(_ body: String) -> JSValue {
        guard let respObj = JSValue(newObjectIn: context) else {
            return JSValue(undefinedIn: context)
        }
        let bodyFunc: @convention(block) () -> String = { body }
        respObj.setObject(bodyFunc, forKeyedSubscript: "body" as NSString)
        return respObj
    }

    static func syncRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]) -> String {
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

        guard let data = resultData else { return "" }
        return CharsetDetector.decode(data: data, response: httpResponse)
    }
}
