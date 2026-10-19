import Foundation

/// 统一的带选项参数的复合 URL 模型 (对齐 Android Legado CustomUrl.kt)
public struct CustomUrl: Equatable, Sendable {
    private var baseRawUrl: String
    private var attributes: [String: String] = [:]

    public init(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commaIndex = trimmed.firstIndex(of: ","),
           trimmed[commaIndex...].contains("{") {
            let optionsJson = String(trimmed[trimmed.index(after: commaIndex)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            self.baseRawUrl = String(trimmed[..<commaIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = optionsJson.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (key, value) in dict {
                    self.attributes[key] = "\(value)"
                }
            }
        } else {
            self.baseRawUrl = trimmed
        }
    }

    public mutating func putAttribute(key: String, value: String?) {
        if let value {
            attributes[key] = value
        } else {
            attributes.removeValue(forKey: key)
        }
    }

    public func getUrl() -> String {
        baseRawUrl
    }

    public func getAttributes() -> [String: String] {
        attributes
    }

    public func toString() -> String {
        guard !attributes.isEmpty, let data = try? JSONSerialization.data(
            withJSONObject: attributes,
            options: [.sortedKeys]),
            let json = String(data: data, encoding: .utf8) else {
            return baseRawUrl
        }
        return "\(baseRawUrl),\(json)"
    }
}
