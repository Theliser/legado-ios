import Foundation
import JavaScriptCore

extension JSEngine {
    func setupWebViewAndUtils(on javaObj: JSValue) {
        typealias WebViewBlock = @convention(block) (JSValue?, JSValue?, JSValue?) -> String
        let webViewBlock: WebViewBlock = { [weak self] _, urlVal, jsVal in
            guard let self else { return "" }
            let urlStr = urlVal?.toString() ?? self.currentBaseUrl
            let jsStr = jsVal?.toString()
            let headers = self.currentSource?.getHeaderMap()
            let res = BrowserVerificationManager.shared.executeHeadlessWebSync(
                url: urlStr,
                webJs: jsStr,
                delayTimeMs: 500,
                headers: headers)
            return res.body
        }
        javaObj.setObject(webViewBlock, forKeyedSubscript: "webView" as NSString)
        context.setObject(webViewBlock, forKeyedSubscript: "webView" as NSString)

        typealias WebViewSourceBlock = @convention(block) (JSValue?, JSValue?, JSValue?, JSValue?) -> String
        let webViewGetSourceBlock: WebViewSourceBlock = { [weak self] _, urlVal, jsVal, _ in
            guard let self else { return "" }
            let urlStr = urlVal?.toString() ?? self.currentBaseUrl
            let jsStr = jsVal?.toString()
            let headers = self.currentSource?.getHeaderMap()
            let res = BrowserVerificationManager.shared.executeHeadlessWebSync(
                url: urlStr,
                webJs: jsStr,
                delayTimeMs: 800,
                headers: headers)
            return res.body
        }
        javaObj.setObject(webViewGetSourceBlock, forKeyedSubscript: "webViewGetSource" as NSString)
        context.setObject(webViewGetSourceBlock, forKeyedSubscript: "webViewGetSource" as NSString)

        let encodeURIBlock: @convention(block) (String, JSValue?) -> String = { str, encVal in
            let enc = encVal?.toString()?.lowercased() ?? "utf-8"
            if enc == "gbk" || enc == "gb2312" {
                return CharsetDetector.percentEncodeGBK(str)
            }
            return str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str
        }
        javaObj.setObject(encodeURIBlock, forKeyedSubscript: "encodeURI" as NSString)
        context.setObject(encodeURIBlock, forKeyedSubscript: "encodeURI" as NSString)

        let htmlFormatBlock: @convention(block) (String) -> String = { str in
            var text = str
            text = text.replacingOccurrences(of: "<br/?>", with: "\n", options: .regularExpression)
            text = text.replacingOccurrences(of: "</p>", with: "\n")
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            text = AnalyzeRule.unescapeHtml(text)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        javaObj.setObject(htmlFormatBlock, forKeyedSubscript: "htmlFormat" as NSString)
        context.setObject(htmlFormatBlock, forKeyedSubscript: "htmlFormat" as NSString)

        setupTimeAndUUIDUtils(on: javaObj)
    }

    private func setupTimeAndUUIDUtils(on javaObj: JSValue) {
        let timeFormatBlock: @convention(block) (JSValue, JSValue?) -> String = { timeVal, formatVal in
            let rawTime = timeVal.toDouble()
            let timeSec = rawTime > 10_000_000_000 ? rawTime / 1000.0 : rawTime
            let date = Date(timeIntervalSince1970: timeSec)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = formatVal?.toString() ?? "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        }
        javaObj.setObject(timeFormatBlock, forKeyedSubscript: "timeFormat" as NSString)
        context.setObject(timeFormatBlock, forKeyedSubscript: "timeFormat" as NSString)

        let timeFormatUTCBlock: @convention(block) (
            JSValue,
            JSValue?,
            JSValue?) -> String = { timeVal, formatVal, shVal in
            let rawTime = timeVal.toDouble()
            let timeSec = rawTime > 10_000_000_000 ? rawTime / 1000.0 : rawTime
            let date = Date(timeIntervalSince1970: timeSec)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = formatVal?.toString() ?? "yyyy-MM-dd HH:mm:ss"
            if let shVal, !shVal.isUndefined, !shVal.isNull {
                let offsetSec = Int(shVal.toDouble() / 1000.0)
                formatter.timeZone = TimeZone(secondsFromGMT: offsetSec)
            } else {
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
            }
            return formatter.string(from: date)
        }
        javaObj.setObject(timeFormatUTCBlock, forKeyedSubscript: "timeFormatUTC" as NSString)
        context.setObject(timeFormatUTCBlock, forKeyedSubscript: "timeFormatUTC" as NSString)

        setupIDAndUABlocks(on: javaObj)
    }

    private func setupIDAndUABlocks(on javaObj: JSValue) {
        let uuidBlock: @convention(block) () -> String = { UUID().uuidString.lowercased() }
        javaObj.setObject(uuidBlock, forKeyedSubscript: "randomUUID" as NSString)
        context.setObject(uuidBlock, forKeyedSubscript: "randomUUID" as NSString)

        let androidIdBlock: @convention(block) () -> String = {
            "a16" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(14).lowercased()
        }
        javaObj.setObject(androidIdBlock, forKeyedSubscript: "androidId" as NSString)
        context.setObject(androidIdBlock, forKeyedSubscript: "androidId" as NSString)

        let getWebViewUABlock: @convention(block) () -> String = {
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " +
                "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        }
        javaObj.setObject(getWebViewUABlock, forKeyedSubscript: "getWebViewUA" as NSString)
        context.setObject(getWebViewUABlock, forKeyedSubscript: "getWebViewUA" as NSString)

        let toURLBlock: @convention(block) (String, JSValue?) -> JSValue? = { [weak self] urlStr, baseVal in
            guard let self else { return nil }
            let base = baseVal?.toString() ?? self.currentBaseUrl
            let cleanUrl: String
            if let commaIdx = urlStr.firstIndex(of: ","), urlStr[commaIdx...].contains("{") {
                cleanUrl = String(urlStr[..<commaIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                cleanUrl = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let resolved = AnalyzeUrl.resolveAbsoluteUrl(cleanUrl, baseUrl: base)
            guard let url = URL(string: resolved) else { return nil }
            let obj = JSValue(newObjectIn: self.context)
            obj?.setObject(url.absoluteString, forKeyedSubscript: "url" as NSString)
            obj?.setObject(url.path, forKeyedSubscript: "path" as NSString)
            obj?.setObject(url.path, forKeyedSubscript: "pathname" as NSString)
            obj?.setObject(url.host ?? "", forKeyedSubscript: "host" as NSString)
            obj?.setObject(url.scheme ?? "", forKeyedSubscript: "protocol" as NSString)
            obj?.setObject(url.query ?? "", forKeyedSubscript: "query" as NSString)
            return obj
        }
        javaObj.setObject(toURLBlock, forKeyedSubscript: "toURL" as NSString)
        context.setObject(toURLBlock, forKeyedSubscript: "toURL" as NSString)
    }
}
