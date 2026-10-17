import Foundation

/// 轻量级 JSONPath 字段解析器，支持 `$.data.list[*]`, `$.book.title`, `a.b.c` 等常见书源规则
public enum JSONPathParser {
    /// 从 JSON 字符串中按路径提取字符串数组
    public static func parse(json: String, path: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        return evaluate(root: root, path: path)
    }

    /// 针对已反序列化的对象进行路径求值
    public static func evaluate(root: Any, path: String) -> [String] {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPath.hasPrefix("@Json:") {
            cleanPath = String(cleanPath.dropFirst(6))
        }
        if cleanPath.hasPrefix("$.") {
            cleanPath = String(cleanPath.dropFirst(2))
        } else if cleanPath.hasPrefix("$") {
            cleanPath = String(cleanPath.dropFirst(1))
        }

        let segments = cleanPath.split(separator: ".").map(String.init)
        return extract(current: root, segments: segments)
    }

    private static func extract(current: Any, segments: [String]) -> [String] {
        guard let first = segments.first else {
            // 到达终点，提取当前节点值
            if let stringVal = current as? String {
                return [stringVal]
            } else if let numVal = current as? NSNumber {
                return [numVal.stringValue]
            } else if let arrayVal = current as? [Any] {
                return arrayVal.compactMap { "\($0)" }
            }
            return []
        }

        let remaining = Array(segments.dropFirst())

        // 处理数组通配符，例如 list[*]
        if first.hasSuffix("[*]") {
            let key = String(first.dropLast(3))
            var arrayNode: [Any]?
            if key.isEmpty {
                arrayNode = current as? [Any]
            } else if let dict = current as? [String: Any] {
                arrayNode = dict[key] as? [Any]
            }

            guard let items = arrayNode else { return [] }
            var results: [String] = []
            for item in items {
                results.append(contentsOf: extract(current: item, segments: remaining))
            }
            return results
        }

        // 普通字典 key
        if let dict = current as? [String: Any], let nextNode = dict[first] {
            return extract(current: nextNode, segments: remaining)
        }

        return []
    }
}
