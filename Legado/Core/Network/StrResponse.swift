import Foundation

/// HTTP 字符串响应封装 (对齐 Android Legado io.legado.app.help.http.StrResponse)
public final class StrResponse: @unchecked Sendable {
    /// 最终跳转请求 URL
    public let url: String
    /// 响应正文文本内容
    public var body: String?
    /// 状态码
    public let code: Int
    /// 状态描述信息
    public let message: String
    /// 全部响应头字典
    public let headers: [String: String]
    /// 是否发生了重定向
    public var isRedirect: Bool
    /// 请求耗时 (毫秒)
    public var callTime: Int

    public var isSuccessful: Bool {
        code >= 200 && code < 300
    }

    public init(
        url: String,
        body: String?,
        code: Int = 200,
        message: String = "OK",
        headers: [String: String] = [:],
        isRedirect: Bool = false,
        callTime: Int = 0) {
        self.url = url
        self.body = body
        self.code = code
        self.message = message
        self.headers = headers
        self.isRedirect = isRedirect
        self.callTime = callTime
    }

    public convenience init(url: String, body: String?) {
        self.init(url: url, body: body, code: 200, message: "OK")
    }
}
