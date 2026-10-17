import Foundation

/// WebDAV 认证与配置模型
public struct WebDAVConfig: Codable, Equatable, Sendable {
    public var serverUrl: String
    public var username: String
    public var password: String
    public var remoteDirectory: String

    public init(
        serverUrl: String = "",
        username: String = "",
        password: String = "",
        remoteDirectory: String = "/Legado/") {
        self.serverUrl = serverUrl
        self.username = username
        self.password = password
        self.remoteDirectory = remoteDirectory
    }

    public var isValid: Bool {
        !serverUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty
    }
}

/// WebDAV 网络异常枚举
public enum WebDAVError: LocalizedError, Sendable {
    case invalidConfig
    case badUrl
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int, message: String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfig:
            return "WebDAV 配置无效，请检查服务器地址与账号密码"

        case .badUrl:
            return "无效的 WebDAV 服务器地址"

        case .unauthorized:
            return "WebDAV 账号或应用密码错误 (HTTP 401)"

        case .forbidden:
            return "WebDAV 访问被拒绝 (HTTP 403)"

        case .notFound:
            return "远程备份文件或目录不存在 (HTTP 404)"

        case let .serverError(code, msg):
            return "WebDAV 服务器异常 (\(code)): \(msg)"

        case let .networkError(msg):
            return "WebDAV 网络请求失败: \(msg)"
        }
    }
}

/// 纯 Swift 原生异步 WebDAV 客户端 (RFC 4918 标准)
public final class WebDAVClient: Sendable {
    public static let shared = WebDAVClient()

    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - 基础请求与连接测试

    /// 测试 WebDAV 连接与鉴权
    public func testConnection(config: WebDAVConfig) async throws -> Bool {
        guard config.isValid else { throw WebDAVError.invalidConfig }
        guard let url = buildUrl(base: config.serverUrl, path: "") else {
            throw WebDAVError.badUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        applyAuth(to: &request, config: config)

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.networkError("未能收到有效 HTTP 响应")
        }

        switch httpResponse.statusCode {
        case 200 ... 207:
            return true

        case 401:
            throw WebDAVError.unauthorized

        case 403:
            throw WebDAVError.forbidden

        default:
            throw WebDAVError.serverError(statusCode: httpResponse.statusCode, message: "连接测试未通过")
        }
    }

    // MARK: - 目录创建 (MKCOL)

    /// 确保远程备份目录存在
    public func createDirectoryIfNeeded(config: WebDAVConfig) async throws {
        guard config.isValid else { throw WebDAVError.invalidConfig }
        let dir = config.remoteDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !dir.isEmpty else { return }

        guard let url = buildUrl(base: config.serverUrl, path: dir + "/") else {
            throw WebDAVError.badUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "MKCOL"
        applyAuth(to: &request, config: config)

        let (_, response) = try await urlSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            // 201 Created 或 405 Method Not Allowed (目录已存在) 均为合规状态
            if (200 ... 207).contains(httpResponse.statusCode) || httpResponse.statusCode == 405 {
                return
            }
            if httpResponse.statusCode == 401 {
                throw WebDAVError.unauthorized
            }
        }
    }

    // MARK: - 文件上传 (PUT)

    /// 上传备份数据包至远程 WebDAV 路径
    public func upload(data: Data, filename: String, config: WebDAVConfig) async throws {
        guard config.isValid else { throw WebDAVError.invalidConfig }
        try await createDirectoryIfNeeded(config: config)

        let cleanDir = config.remoteDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let remotePath = cleanDir.isEmpty ? filename : "\(cleanDir)/\(filename)"

        guard let targetUrl = buildUrl(base: config.serverUrl, path: remotePath) else {
            throw WebDAVError.badUrl
        }

        var request = URLRequest(url: targetUrl)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        applyAuth(to: &request, config: config)

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.networkError("上传未收到 HTTP 响应")
        }

        switch httpResponse.statusCode {
        case 200 ... 204:
            return

        case 401:
            throw WebDAVError.unauthorized

        case 403:
            throw WebDAVError.forbidden

        default:
            throw WebDAVError.serverError(statusCode: httpResponse.statusCode, message: "文件上传失败")
        }
    }

    // MARK: - 文件下载 (GET)

    /// 从远程 WebDAV 服务器下载指定文件
    public func download(filename: String, config: WebDAVConfig) async throws -> Data {
        guard config.isValid else { throw WebDAVError.invalidConfig }
        let cleanDir = config.remoteDirectory.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let remotePath = cleanDir.isEmpty ? filename : "\(cleanDir)/\(filename)"

        guard let targetUrl = buildUrl(base: config.serverUrl, path: remotePath) else {
            throw WebDAVError.badUrl
        }

        var request = URLRequest(url: targetUrl)
        request.httpMethod = "GET"
        applyAuth(to: &request, config: config)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.networkError("下载未收到 HTTP 响应")
        }

        switch httpResponse.statusCode {
        case 200 ... 206:
            return data

        case 401:
            throw WebDAVError.unauthorized

        case 404:
            throw WebDAVError.notFound

        default:
            throw WebDAVError.serverError(statusCode: httpResponse.statusCode, message: "文件下载失败")
        }
    }

    // MARK: - 内部请求构建工具

    private func applyAuth(to request: inout URLRequest, config: WebDAVConfig) {
        let credential = "\(config.username):\(config.password)"
        if let credData = credential.data(using: .utf8) {
            let base64 = credData.base64EncodedString()
            request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("Legado-iOS/1.0", forHTTPHeaderField: "User-Agent")
    }

    private func buildUrl(base: String, path: String) -> URL? {
        var baseString = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseString.hasSuffix("/") {
            baseString += "/"
        }
        guard let baseUrl = URL(string: baseString) else { return nil }
        return URL(string: path, relativeTo: baseUrl)?.absoluteURL
    }
}
