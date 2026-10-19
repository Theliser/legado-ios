import Foundation
import WebKit

/// 浏览器验证返回结果结构体 (对齐 Android Legado StrResponse)
public struct BrowserVerificationResult: Sendable {
    public let url: String
    public let body: String

    public init(url: String, body: String) {
        self.url = url
        self.body = body
    }
}

/// 浏览器交互式验证管理器 (处理 Cloudflare 403 / Turnstile / 图片验证码挑战)
/// 对齐 Android Legado SourceVerificationHelp / java.startBrowserAwait
public final class BrowserVerificationManager: @unchecked Sendable {
    public static let shared = BrowserVerificationManager()

    private let lock = NSLock()
    private var pendingContinuations: [String: CheckedContinuation<BrowserVerificationResult, Error>] = [:]
    private var mockVerificationHandler: (@Sendable (String, String) async throws -> BrowserVerificationResult)?

    private init() {}

    /// 注册测试模拟处理器 (用于单元测试中模拟用户过盾)
    public func setMockHandler(
        _ handler: (@Sendable (String, String) async throws -> BrowserVerificationResult)?) {
        lock.lock()
        defer { lock.unlock() }
        mockVerificationHandler = handler
    }

    /// 异步发起浏览器过盾验证请求
    public func verify(
        url: String,
        title: String = "",
        sourceOrigin: String = "",
        refetchAfterSuccess: Bool = true) async throws -> BrowserVerificationResult {
        // 如果注册了模拟处理器（测试环境），直接走模拟
        if let mock = mockVerificationHandler {
            let res = try await mock(url, title)
            // 自动同步解析到的 cookie 到 CookieStore
            if !res.body.isEmpty {
                let clearance = "cf_clearance=simulated_token_\(Date().timeIntervalSince1970)"
                CookieStore.shared.setCookie(url: url, cookie: clearance)
            }
            return res
        }

        let key = sourceOrigin.isEmpty ? url : sourceOrigin
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            pendingContinuations[key] = continuation
            lock.unlock()

            // 发布通知唤起前台 UI (若有 UI 监听)
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .browserVerificationRequested,
                    object: nil,
                    userInfo: [
                        "url": url,
                        "title": title,
                        "sourceOrigin": sourceOrigin,
                        "refetchAfterSuccess": refetchAfterSuccess,
                    ])
            }
        }
    }

    /// 同步阻塞等待浏览器过盾结果 (供 JavaScriptCore 脚本引擎的 java.startBrowserAwait 调用)
    public func verifySync(
        url: String,
        title: String = "",
        refetchAfterSuccess: Bool = true) -> BrowserVerificationResult {
        var finalResult = BrowserVerificationResult(url: url, body: "")
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                let res = try await self.verify(
                    url: url,
                    title: title,
                    sourceOrigin: url,
                    refetchAfterSuccess: refetchAfterSuccess)
                finalResult = res
            } catch {
                finalResult = BrowserVerificationResult(url: url, body: "")
            }
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 30.0)
        return finalResult
    }

    /// 完成验证并写入结果，恢复挂起任务 (由 UI 层或自动过盾检测器回调)
    public func completeVerification(
        key: String,
        resultUrl: String,
        html: String,
        cookies: [String: String]? = nil) {
        if let cookies, !cookies.isEmpty {
            let cookieHeader = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            CookieStore.shared.setCookie(url: resultUrl, cookie: cookieHeader)
        }

        lock.lock()
        let continuation = pendingContinuations.removeValue(forKey: key)
        lock.unlock()

        continuation?.resume(returning: BrowserVerificationResult(url: resultUrl, body: html))
    }

    /// 取消或失败验证
    public func failVerification(key: String, error: Error) {
        lock.lock()
        let continuation = pendingContinuations.removeValue(forKey: key)
        lock.unlock()

        continuation?.resume(throwing: error)
    }

    /// 后台无头 WebKit 执行指定页面的渲染与 webJs 注入 (对标 Android Legado BackstageWebView)
    @MainActor
    public func executeHeadlessWeb(
        url: String,
        webJs: String? = nil,
        delayTimeMs: Int = 0,
        headers: [String: String]? = nil) async throws -> BrowserVerificationResult {
        if let mock = mockVerificationHandler {
            return try await mock(url, "HeadlessWeb")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let webView = WKWebView(frame: .zero)
            let delegate = HeadlessWebDelegate(
                webJs: webJs,
                delayTimeMs: delayTimeMs,
                continuation: continuation)
            objc_setAssociatedObject(webView, &headlessDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            webView.navigationDelegate = delegate

            guard let targetUrl = URL(string: url) else {
                continuation.resume(throwing: URLError(.badURL))
                return
            }

            var request = URLRequest(url: targetUrl)
            if let headers {
                for (headerKey, headerValue) in headers {
                    request.setValue(headerValue, forHTTPHeaderField: headerKey)
                }
            }
            let cookie = CookieStore.shared.getCookie(url: url)
            if !cookie.isEmpty {
                request.setValue(cookie, forHTTPHeaderField: "Cookie")
            }
            webView.load(request)
        }
    }

    /// 同步阻塞方式执行无头 WebKit 渲染 (供规则引擎内部调用)
    public func executeHeadlessWebSync(
        url: String,
        webJs: String? = nil,
        delayTimeMs: Int = 0,
        headers: [String: String]? = nil) -> BrowserVerificationResult {
        var finalResult = BrowserVerificationResult(url: url, body: "")
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            do {
                finalResult = try await self.executeHeadlessWeb(
                    url: url,
                    webJs: webJs,
                    delayTimeMs: delayTimeMs,
                    headers: headers)
            } catch {
                finalResult = BrowserVerificationResult(url: url, body: "")
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 20.0)
        return finalResult
    }
}

private var headlessDelegateKey: UInt8 = 0

private final class HeadlessWebDelegate: NSObject, WKNavigationDelegate {
    private let webJs: String?
    private let delayTimeMs: Int
    private var continuation: CheckedContinuation<BrowserVerificationResult, Error>?

    init(
        webJs: String?,
        delayTimeMs: Int,
        continuation: CheckedContinuation<BrowserVerificationResult, Error>) {
        self.webJs = webJs
        self.delayTimeMs = delayTimeMs
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        Task { @MainActor in
            if self.delayTimeMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(self.delayTimeMs) * 1_000_000)
            }
            if let script = self.webJs, !script.isEmpty {
                _ = try? await webView.evaluateJavaScript(script)
            }
            let html = (try? await webView.evaluateJavaScript("document.documentElement.outerHTML")) as? String ?? ""
            let currentUrl = webView.url?.absoluteString ?? ""

            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            for cookie in cookies {
                CookieStore.shared.setCookie(url: currentUrl, cookie: "\(cookie.name)=\(cookie.value)")
            }

            self.continuation?.resume(returning: BrowserVerificationResult(url: currentUrl, body: html))
            self.continuation = nil
        }
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

public extension Notification.Name {
    static let browserVerificationRequested = Notification.Name("LegadoBrowserVerificationRequested")
}
