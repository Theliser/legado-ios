import Foundation
import JavaScriptCore

struct SyncHTTPResponse {
    let body: String
    let headers: [String: String]
    let cookies: [String: String]
    let data: Data?
    let statusCode: Int
    let url: String
}

extension JSEngine {
    func setupJavaNetworkMethods(on javaObj: JSValue) {
        // ajax: 兼容 ajax(url) 与 ajax(url, options) 及 options 包含 method/body/headers
        let ajax: @convention(block) (JSValue, JSValue?) -> String = { [weak self] urlVal, optVal in
            guard let self else { return "" }
            return self.executeAjax(urlVal: urlVal, optVal: optVal)
        }
        javaObj.setObject(ajax, forKeyedSubscript: "ajax" as NSString)
        context.setObject(ajax, forKeyedSubscript: "ajax" as NSString)

        // ajaxAll: 批量并发抓取多链接
        let ajaxAll: @convention(block) (JSValue, JSValue?) -> JSValue = { [weak self] urlListVal, _ in
            guard let self else { return JSValue(newArrayIn: self?.context) }
            return self.executeAjaxAll(urlListVal: urlListVal)
        }
        javaObj.setObject(ajaxAll, forKeyedSubscript: "ajaxAll" as NSString)
        context.setObject(ajaxAll, forKeyedSubscript: "ajaxAll" as NSString)

        // connect: 对齐 Android Legado connect(url, header, timeout) -> StrResponse
        typealias ConnectBlock = @convention(block) (JSValue, JSValue?, JSValue?) -> JSValue
        let connect: ConnectBlock = { [weak self] urlVal, headerVal, timeoutVal in
            guard let self else { return JSValue(undefinedIn: self?.context) }
            return self.executeConnect(urlVal: urlVal, headerVal: headerVal, timeoutVal: timeoutVal)
        }
        javaObj.setObject(connect, forKeyedSubscript: "connect" as NSString)
        context.setObject(connect, forKeyedSubscript: "connect" as NSString)
        javaObj.setObject(connect, forKeyedSubscript: "get" as NSString)
        context.setObject(connect, forKeyedSubscript: "get" as NSString)
        javaObj.setObject(connect, forKeyedSubscript: "head" as NSString)

        setupPostAndBrowserAwait(on: javaObj)
        setupWebViewAndUtils(on: javaObj)
    }

    private func setupPostAndBrowserAwait(on javaObj: JSValue) {
        let post: @convention(block) (String, String, JSValue?) -> JSValue = { [weak self] urlStr, body, headersVal in
            guard let self else { return JSValue(newObjectIn: self?.context) }
            let headers: [String: String]
            if let dict = headersVal?.toObject() as? [String: String] {
                headers = dict
            } else if let str = headersVal?.toString(),
                      let data = str.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var headerMap: [String: String] = [:]
                for (key, val) in dict {
                    headerMap[key] = "\(val)"
                }
                headers = headerMap
            } else {
                headers = [:]
            }
            let absUrlStr = AnalyzeUrl.resolveAbsoluteUrl(urlStr, baseUrl: self.currentBaseUrl)
            guard let url = URL(string: absUrlStr) else {
                return JSValue(newObjectIn: self.context)
            }
            let res = Self.syncRequest(url: url, method: "POST", body: body.data(using: .utf8), headers: headers)
            return self.wrapResponse(res)
        }
        javaObj.setObject(post, forKeyedSubscript: "post" as NSString)
        context.setObject(post, forKeyedSubscript: "post" as NSString)

        typealias BrowserAwaitBlock = @convention(block) (String, String, JSValue?) -> JSValue
        let startBrowserAwait: BrowserAwaitBlock = { [weak self] urlStr, titleStr, refetchVal in
            guard let self else { return JSValue(undefinedIn: self?.context) }
            let refetch = refetchVal?.toBool() ?? true
            let result = BrowserVerificationManager.shared.verifySync(
                url: urlStr,
                title: titleStr,
                refetchAfterSuccess: refetch)
            return self.wrapBrowserResponse(result)
        }
        javaObj.setObject(startBrowserAwait, forKeyedSubscript: "startBrowserAwait" as NSString)
    }

    func executeAjax(urlVal: JSValue, optVal: JSValue?) -> String {
        let rawUrlStr: String
        if urlVal.isArray {
            rawUrlStr = urlVal.toArray()?.first.flatMap { "\($0)" } ?? ""
        } else {
            rawUrlStr = urlVal.toString() ?? ""
        }

        let trimmedUrl = rawUrlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return "" }

        var finalUrlCandidate = trimmedUrl
        if let opt = optVal, !opt.isUndefined, !opt.isNull, opt.isObject {
            let jsonEngine = context.objectForKeyedSubscript("JSON" as NSString)
            let stringify = jsonEngine?.objectForKeyedSubscript("stringify" as NSString)
            if let stringified = stringify?.call(withArguments: [opt]), !stringified.isUndefined, !stringified.isNull {
                let jsonStr = stringified.toString() ?? ""
                if !trimmedUrl.contains(",") {
                    finalUrlCandidate = trimmedUrl + "," + jsonStr
                }
            }
        }

        let resp = requestWithAnalyzeUrl(urlCandidate: finalUrlCandidate)
        return resp.body
    }

    func executeAjaxAll(urlListVal: JSValue) -> JSValue {
        guard let list = urlListVal.toArray() as? [String] else {
            return JSValue(newArrayIn: context)
        }
        guard let arrayVal = JSValue(newArrayIn: context) else {
            return JSValue(undefinedIn: context)
        }
        for (idx, urlStr) in list.enumerated() {
            let resp = requestWithAnalyzeUrl(urlCandidate: urlStr)
            let wrapped = wrapResponse(resp)
            arrayVal.setValue(wrapped, at: idx)
        }
        return arrayVal
    }

    func executeConnect(urlVal: JSValue, headerVal: JSValue?, timeoutVal _: JSValue?) -> JSValue {
        let rawUrlStr: String
        if urlVal.isArray {
            rawUrlStr = urlVal.toArray()?.first.flatMap { "\($0)" } ?? ""
        } else {
            rawUrlStr = urlVal.toString() ?? ""
        }

        let trimmedUrl = rawUrlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUrl.isEmpty else { return JSValue(undefinedIn: context) }

        var finalUrlCandidate = trimmedUrl
        if let header = headerVal, !header.isUndefined, !header.isNull {
            var headerJsonStr = ""
            if header.isString {
                headerJsonStr = header.toString() ?? ""
            } else if header.isObject {
                let jsonEngine = context.objectForKeyedSubscript("JSON" as NSString)
                let stringify = jsonEngine?.objectForKeyedSubscript("stringify" as NSString)
                let stringified = stringify?.call(withArguments: [header])
                if let stringified, !stringified.isUndefined, !stringified.isNull {
                    headerJsonStr = stringified.toString() ?? ""
                }
            }
            if !headerJsonStr.isEmpty, !trimmedUrl.contains(",") {
                finalUrlCandidate = trimmedUrl + ",{\"headers\":" + headerJsonStr + "}"
            }
        }

        let resp = requestWithAnalyzeUrl(urlCandidate: finalUrlCandidate)
        return wrapResponse(resp)
    }

    func requestWithAnalyzeUrl(urlCandidate: String) -> SyncHTTPResponse {
        do {
            let analyzeUrl = try AnalyzeUrl(
                rawUrl: urlCandidate,
                baseUrl: currentBaseUrl,
                headerJson: currentHeaderJson,
                source: currentSource)

            if analyzeUrl.useWebView {
                let res = BrowserVerificationManager.shared.executeHeadlessWebSync(
                    url: analyzeUrl.url.absoluteString,
                    webJs: analyzeUrl.webJs,
                    delayTimeMs: analyzeUrl.webViewDelayTime ?? 0,
                    headers: analyzeUrl.headers)
                var finalBody = res.body
                if let bodyJs = analyzeUrl.bodyJs, !bodyJs.isEmpty {
                    let engine = JSEngine()
                    finalBody = engine.evaluate(script: bodyJs, bindings: [
                        "result": finalBody,
                        "baseUrl": analyzeUrl.url.absoluteString,
                    ]) ?? finalBody
                }
                return SyncHTTPResponse(
                    body: finalBody,
                    headers: [:],
                    cookies: [:],
                    data: finalBody.data(using: .utf8),
                    statusCode: 200,
                    url: analyzeUrl.url.absoluteString)
            }

            var resp = Self.syncRequest(
                url: analyzeUrl.url,
                method: analyzeUrl.method,
                body: analyzeUrl.body,
                headers: analyzeUrl.headers)

            if let bodyJs = analyzeUrl.bodyJs, !bodyJs.isEmpty {
                let engine = JSEngine()
                let transformed = engine.evaluate(script: bodyJs, bindings: [
                    "result": resp.body,
                    "baseUrl": analyzeUrl.url.absoluteString,
                ]) ?? resp.body
                resp = SyncHTTPResponse(
                    body: transformed,
                    headers: resp.headers,
                    cookies: resp.cookies,
                    data: transformed.data(using: .utf8),
                    statusCode: resp.statusCode,
                    url: resp.url)
            }
            return resp
        } catch {
            let absUrlStr = AnalyzeUrl.resolveAbsoluteUrl(urlCandidate, baseUrl: currentBaseUrl)
            if let fallbackUrl = URL(string: absUrlStr) {
                var defaultHeaders: [String: String] = [:]
                if let hJson = currentHeaderJson {
                    let parsed = AnalyzeUrl.parseHeaderJson(hJson, baseUrl: currentBaseUrl)
                    AnalyzeUrl.mergeHeaders(parsed, into: &defaultHeaders)
                }
                return Self.syncRequest(url: fallbackUrl, headers: defaultHeaders)
            }
            return SyncHTTPResponse(body: "", headers: [:], cookies: [:], data: nil, statusCode: 0, url: urlCandidate)
        }
    }

    func wrapBrowserResponse(_ res: BrowserVerificationResult) -> JSValue {
        guard let respObj = JSValue(newObjectIn: context) else {
            return JSValue(undefinedIn: context)
        }
        let bodyFunc: @convention(block) () -> String = { res.body }
        let urlFunc: @convention(block) () -> String = { res.url }
        respObj.setObject(bodyFunc, forKeyedSubscript: "body" as NSString)
        respObj.setObject(urlFunc, forKeyedSubscript: "url" as NSString)
        return respObj
    }

    func wrapResponse(_ res: SyncHTTPResponse) -> JSValue {
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
        let urlFunc: @convention(block) () -> String = { res.url }
        let codeFunc: @convention(block) () -> Int = { res.statusCode }
        let isSuccessFunc: @convention(block) () -> Bool = { res.statusCode >= 200 && res.statusCode < 300 }
        let rawFunc: @convention(block) () -> JSValue = { respObj }

        respObj.setObject(bodyFunc, forKeyedSubscript: "body" as NSString)
        respObj.setObject(bodyFunc, forKeyedSubscript: "text" as NSString)
        respObj.setObject(headerFunc, forKeyedSubscript: "header" as NSString)
        respObj.setObject(res.headers, forKeyedSubscript: "headers" as NSString)
        respObj.setObject(cookieFunc, forKeyedSubscript: "cookie" as NSString)
        respObj.setObject(res.cookies, forKeyedSubscript: "cookies" as NSString)
        respObj.setObject(urlFunc, forKeyedSubscript: "url" as NSString)
        respObj.setObject(codeFunc, forKeyedSubscript: "code" as NSString)
        respObj.setObject(isSuccessFunc, forKeyedSubscript: "isSuccessful" as NSString)
        respObj.setObject(rawFunc, forKeyedSubscript: "raw" as NSString)

        // 对齐 Android Legado StrResponse：在 JS 中使 res.body / res.url / res.code 兼具属性与方法特性
        let setupScript = """
        (function(r) {
            var origBody = r.body;
            var b = function() { return origBody(); };
            b.toString = function() { return origBody(); };
            b.valueOf = function() { return origBody(); };
            r.body = b;
            r.text = b;

            var origUrl = r.url;
            var u = function() { return origUrl(); };
            u.toString = function() { return origUrl(); };
            r.url = u;

            var origCode = r.code;
            var c = function() { return origCode(); };
            c.toString = function() { return "" + origCode(); };
            c.valueOf = function() { return origCode(); };
            r.code = c;

            var origIsSuccess = r.isSuccessful;
            var s = function() { return origIsSuccess(); };
            s.toString = function() { return origIsSuccess() ? "true" : "false"; };
            s.valueOf = function() { return origIsSuccess(); };
            r.isSuccessful = s;
        })
        """
        if let setupFn = context.evaluateScript(setupScript) {
            setupFn.call(withArguments: [respObj])
        }

        return respObj
    }

    static func syncRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval = 15.0) -> SyncHTTPResponse {
        let request = createSyncURLRequest(
            url: url,
            method: method,
            body: body,
            headers: headers,
            timeout: timeout)

        var resultData: Data?
        var httpResponse: HTTPURLResponse?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            resultData = data
            httpResponse = response as? HTTPURLResponse
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout)

        let (headerDict, cookieDict) = extractResponseHeadersAndCookies(response: httpResponse, url: url)
        let statusCode = httpResponse?.statusCode ?? (resultData != nil ? 200 : 0)
        let finalUrlStr = httpResponse?.url?.absoluteString ?? url.absoluteString

        guard let data = resultData else {
            return SyncHTTPResponse(
                body: "",
                headers: headerDict,
                cookies: cookieDict,
                data: nil,
                statusCode: statusCode,
                url: finalUrlStr)
        }
        let bodyStr = CharsetDetector.decode(data: data, response: httpResponse)
        return SyncHTTPResponse(
            body: bodyStr,
            headers: headerDict,
            cookies: cookieDict,
            data: data,
            statusCode: statusCode,
            url: finalUrlStr)
    }

    private static func createSyncURLRequest(
        url: URL,
        method: String,
        body: Data?,
        headers: [String: String],
        timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = timeout
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        var customUA: String?
        for (key, val) in headers {
            if key.caseInsensitiveCompare("User-Agent") == .orderedSame {
                customUA = val
            } else {
                request.setValue(val, forHTTPHeaderField: key)
            }
        }
        if let customUA {
            request.setValue(customUA, forHTTPHeaderField: "User-Agent")
        }

        let persistentCookie = CookieStore.shared.getCookie(url: url.absoluteString)
        if !persistentCookie.isEmpty {
            request.setValue(persistentCookie, forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private static func extractResponseHeadersAndCookies(
        response: HTTPURLResponse?,
        url: URL) -> (headers: [String: String], cookies: [String: String]) {
        var headerDict: [String: String] = [:]
        var cookieDict: [String: String] = [:]
        guard let response else { return (headerDict, cookieDict) }

        for (headerKey, headerVal) in response.allHeaderFields {
            headerDict[String(describing: headerKey)] = String(describing: headerVal)
        }
        if let stringHeaders = response.allHeaderFields as? [String: String] {
            if let setCookie = stringHeaders["Set-Cookie"] ?? stringHeaders["set-cookie"] {
                CookieStore.shared.setCookie(url: url.absoluteString, cookie: setCookie)
            }
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: stringHeaders, for: url)
            for cookie in cookies {
                cookieDict[cookie.name] = cookie.value
            }
        }
        return (headerDict, cookieDict)
    }
}
