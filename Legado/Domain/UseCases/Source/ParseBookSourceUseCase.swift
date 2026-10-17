import Foundation

/// 书源导入解析用例，支持解析单个书源 JSON、书源数组 JSON 以及网络 URL 导入
public struct ParseBookSourceUseCase: Sendable {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = .shared) {
        self.httpClient = httpClient
    }

    /// 从 JSON 文本中解析书源（支持单对象或数组）
    public func parse(json: String) throws -> [BookSource] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw BookSourceParseError.invalidData
        }

        let decoder = JSONDecoder()

        // 尝试数组反序列化
        if trimmed.hasPrefix("[") {
            return try decoder.decode([BookSource].self, from: data)
        } else if trimmed.hasPrefix("{") {
            let single = try decoder.decode(BookSource.self, from: data)
            return [single]
        } else {
            throw BookSourceParseError.invalidFormat
        }
    }

    /// 从网络 URL 获取书源并解析
    public func importFromUrl(urlString: String) async throws -> [BookSource] {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw BookSourceParseError.invalidUrl
        }

        let rawContent = try await httpClient.get(url: url)
        return try parse(json: rawContent)
    }
}

public enum BookSourceParseError: LocalizedError {
    case invalidUrl
    case invalidData
    case invalidFormat

    public var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "无效的书源导入网络地址"

        case .invalidData:
            return "书源数据编码异常"

        case .invalidFormat:
            return "书源格式不符合 JSON 规范"
        }
    }
}
