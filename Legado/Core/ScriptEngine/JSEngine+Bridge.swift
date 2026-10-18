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

        // 1. 网络请求: java.ajax(url)
        let ajax: @convention(block) (String) -> String = { urlString in
            guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return "" }
            return Self.syncRequest(url: url)
        }
        javaObj.setObject(ajax, forKeyedSubscript: "ajax" as NSString)

        // 2. 网络请求: java.get(url, headers)
        let get: @convention(block) (String, JSValue?) -> JSValue = { [weak self] urlString, headersVal in
            guard let self, let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return JSValue(newObjectIn: self?.context)
            }
            let headers = (headersVal?.toObject() as? [String: String]) ?? [:]
            let res = Self.syncRequest(url: url, method: "GET", headers: headers)
            return self.wrapResponse(res)
        }
        javaObj.setObject(get, forKeyedSubscript: "get" as NSString)

        // 3. 网络请求: java.post(url, body, headers)
        let post: @convention(block) (String, String, JSValue?) -> JSValue = { [weak self] urlStr, body, headersVal in
            guard let self, let url = URL(string: urlStr.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return JSValue(newObjectIn: self?.context)
            }
            let headers = (headersVal?.toObject() as? [String: String]) ?? [:]
            let res = Self.syncRequest(url: url, method: "POST", body: body.data(using: .utf8), headers: headers)
            return self.wrapResponse(res)
        }
        javaObj.setObject(post, forKeyedSubscript: "post" as NSString)

        // 4. 键值存取: java.put(key, val) / java.get(key)
        let putVal: @convention(block) (String, String) -> Void = { [weak self] key, val in
            self?.memoryStorage[key] = val
        }
        let getVal: @convention(block) (String) -> String = { [weak self] key in
            self?.memoryStorage[key] ?? ""
        }
        javaObj.setObject(putVal, forKeyedSubscript: "put" as NSString)
        javaObj.setObject(getVal, forKeyedSubscript: "getString" as NSString)

        // 5. 编解码方法
        setupEncodingMethods(on: javaObj)

        context.setObject(javaObj, forKeyedSubscript: "java" as NSString)
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
