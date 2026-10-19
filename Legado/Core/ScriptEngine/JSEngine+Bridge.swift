import CommonCrypto
import CryptoKit
import Foundation
import JavaScriptCore

extension JSEngine {
    func setupBridges() {
        setupJavaBridge()
        setupCookieBridge()
        setupCacheBridge()
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
        setupQueryTTFMethods(on: javaObj)
        context.setObject(javaObj, forKeyedSubscript: "java" as NSString)
    }

    private func setupJavaStorageMethods(on javaObj: JSValue) {
        let putVal: @convention(block) (String, String) -> Void = { [weak self] key, val in
            self?.memoryStorage[key] = val
        }
        let getVal: @convention(block) (String) -> String = { [weak self] key in
            self?.memoryStorage[key] ?? ""
        }
        let getCookieVal: @convention(block) (String) -> String = { url in
            CookieStore.shared.getCookie(url: url)
        }
        let setCookieVal: @convention(block) (String, String) -> Void = { url, cookie in
            CookieStore.shared.setCookie(url: url, cookie: cookie)
        }
        javaObj.setObject(putVal, forKeyedSubscript: "put" as NSString)
        javaObj.setObject(getVal, forKeyedSubscript: "get" as NSString)
        javaObj.setObject(getCookieVal, forKeyedSubscript: "getCookie" as NSString)
        javaObj.setObject(setCookieVal, forKeyedSubscript: "setCookie" as NSString)
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
            if rule.hasPrefix("$.") || rule.lowercased().hasPrefix("@json:") {
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
            if rule.hasPrefix("$.") || rule.lowercased().hasPrefix("@json:") {
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
        let toNumChapterFunc: @convention(block) (String) -> String = { input in
            Self.toNumChapter(input)
        }

        javaObj.setObject(t2s, forKeyedSubscript: "t2s" as NSString)
        javaObj.setObject(s2t, forKeyedSubscript: "s2t" as NSString)
        javaObj.setObject(toNumChapterFunc, forKeyedSubscript: "toNumChapter" as NSString)

        context.setObject(t2s, forKeyedSubscript: "t2s" as NSString)
        context.setObject(s2t, forKeyedSubscript: "s2t" as NSString)
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
        let log: @convention(block) (String) -> Void = { _ in }

        javaObj.setObject(createCrypto, forKeyedSubscript: "createSymmetricCrypto" as NSString)
        javaObj.setObject(aesDecode, forKeyedSubscript: "aesBase64DecodeToString" as NSString)
        javaObj.setObject(log, forKeyedSubscript: "toast" as NSString)
        javaObj.setObject(log, forKeyedSubscript: "longToast" as NSString)
        javaObj.setObject(log, forKeyedSubscript: "log" as NSString)
    }

    private func setupCookieBridge() {
        guard let cookieObj = JSValue(newObjectIn: context) else { return }
        let removeCookie: @convention(block) (String) -> Void = { url in
            CookieStore.shared.removeCookie(url: url)
        }
        let getCookie: @convention(block) (String) -> String = { url in
            CookieStore.shared.getCookie(url: url)
        }
        let setCookie: @convention(block) (String, String) -> Void = { url, cookie in
            CookieStore.shared.setCookie(url: url, cookie: cookie)
        }
        let replaceCookie: @convention(block) (String, String) -> Void = { url, cookie in
            CookieStore.shared.replaceCookie(url: url, cookie: cookie)
        }
        let getKey: @convention(block) (String, String) -> String = { url, key in
            CookieStore.shared.getKey(url: url, key: key)
        }
        let cookieToMap: @convention(block) (String) -> [String: String] = { cookie in
            CookieStore.shared.cookieToMap(cookie)
        }
        let mapToCookie: @convention(block) ([String: String]) -> String = { map in
            CookieStore.shared.mapToCookie(map)
        }

        cookieObj.setObject(removeCookie, forKeyedSubscript: "removeCookie" as NSString)
        cookieObj.setObject(getCookie, forKeyedSubscript: "getCookie" as NSString)
        cookieObj.setObject(setCookie, forKeyedSubscript: "setCookie" as NSString)
        cookieObj.setObject(replaceCookie, forKeyedSubscript: "replaceCookie" as NSString)
        cookieObj.setObject(getKey, forKeyedSubscript: "getKey" as NSString)
        cookieObj.setObject(cookieToMap, forKeyedSubscript: "cookieToMap" as NSString)
        cookieObj.setObject(mapToCookie, forKeyedSubscript: "mapToCookie" as NSString)
        context.setObject(cookieObj, forKeyedSubscript: "cookie" as NSString)
    }

    private func setupCacheBridge() {
        guard let cacheObj = JSValue(newObjectIn: context) else { return }
        let put: @convention(block) (String, JSValue, JSValue?) -> Void = { key, val, saveTime in
            let saveSeconds = saveTime?.toInt32() ?? 0
            CacheManager.shared.put(key, val.toObject() ?? "", saveTime: Int(saveSeconds))
        }
        let get: @convention(block) (String) -> String? = { key in
            CacheManager.shared.get(key)
        }
        let delete: @convention(block) (String) -> Void = { key in
            CacheManager.shared.delete(key)
        }
        let putMemory: @convention(block) (String, JSValue) -> Void = { key, val in
            CacheManager.shared.putMemory(key, val.toObject() ?? "")
        }
        let getFromMemory: @convention(block) (String) -> Any? = { key in
            CacheManager.shared.getFromMemory(key)
        }
        let deleteMemory: @convention(block) (String) -> Void = { key in
            CacheManager.shared.deleteMemory(key)
        }

        cacheObj.setObject(put, forKeyedSubscript: "put" as NSString)
        cacheObj.setObject(get, forKeyedSubscript: "get" as NSString)
        cacheObj.setObject(delete, forKeyedSubscript: "delete" as NSString)
        cacheObj.setObject(putMemory, forKeyedSubscript: "putMemory" as NSString)
        cacheObj.setObject(getFromMemory, forKeyedSubscript: "getFromMemory" as NSString)
        cacheObj.setObject(deleteMemory, forKeyedSubscript: "deleteMemory" as NSString)
        context.setObject(cacheObj, forKeyedSubscript: "cache" as NSString)
    }

    private func setupQueryTTFMethods(on javaObj: JSValue) {
        let queryTTFBlock: @convention(block) (JSValue?, JSValue?) -> JSValue? = { [weak self] dataVal, useCacheVal in
            guard let self, let dataVal, !dataVal.isNull, !dataVal.isUndefined else { return nil }
            let useCache = useCacheVal?.toBool() ?? true

            var fontData: Data?

            if dataVal.isString {
                let str = dataVal.toString() ?? ""
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                    if useCache, let cached = QueryTTFCache.shared.get(key: trimmed) {
                        return JSValue(object: cached, in: self.context)
                    }
                    if let url = URL(string: trimmed) {
                        fontData = Self.syncRequest(url: url).data
                    }
                } else {
                    fontData = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters)
                }
            } else if let bytes = dataVal.toArray() as? [UInt8] {
                fontData = Data(bytes)
            } else if let bytes = dataVal.toArray() as? [Int] {
                fontData = Data(bytes.map { UInt8($0 & 0xFF) })
            }

            guard let fontData, let ttf = QueryTTF(data: fontData) else { return nil }
            if useCache {
                let key = QueryTTFCache.cacheKey(for: fontData)
                QueryTTFCache.shared.put(key: key, ttf: ttf)
            }
            return JSValue(object: ttf, in: self.context)
        }

        javaObj.setObject(queryTTFBlock, forKeyedSubscript: "queryTTF" as NSString)
        javaObj.setObject(queryTTFBlock, forKeyedSubscript: "queryBase64TTF" as NSString)
        context.setObject(queryTTFBlock, forKeyedSubscript: "queryTTF" as NSString)
        context.setObject(queryTTFBlock, forKeyedSubscript: "queryBase64TTF" as NSString)

        typealias ReplaceFontBlock = @convention(block) (String, JSValue?, JSValue?, JSValue?) -> String
        let replaceFontBlock: ReplaceFontBlock = { text, errVal, corrVal, filterVal in
            let errTTF = errVal?.toObject() as? QueryTTF
            let corrTTF = corrVal?.toObject() as? QueryTTF
            let filter = filterVal?.toBool() ?? false
            return QueryTTF.replaceFont(
                text: text,
                errorQueryTTF: errTTF,
                correctQueryTTF: corrTTF,
                filter: filter)
        }

        javaObj.setObject(replaceFontBlock, forKeyedSubscript: "replaceFont" as NSString)
        context.setObject(replaceFontBlock, forKeyedSubscript: "replaceFont" as NSString)
    }
}
