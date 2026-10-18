import Foundation

/// 轻量级 JSONPath 字段解析器，支持 `$.data.list[*]`, `$.book.title`, `$..book_data[0]`, `||` 回退及 `&&` 合并等常见书源规则
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
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("||") {
            let candidates = trimmed.components(separatedBy: "||")
            for candidate in candidates {
                let res = evaluateSingle(root: root, path: candidate)
                if !res.isEmpty {
                    return res
                }
            }
            return []
        }

        if trimmed.contains("&&") {
            let parts = trimmed.components(separatedBy: "&&")
            var combined: [String] = []
            for part in parts {
                combined.append(contentsOf: evaluateSingle(root: root, path: part))
            }
            return combined
        }

        return evaluateSingle(root: root, path: trimmed)
    }

    private static func evaluateSingle(root: Any, path: String) -> [String] {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPath.lowercased().hasPrefix("@json:") {
            cleanPath = String(cleanPath.dropFirst(6))
        }

        // 处理深度递归扫描 $..field
        if cleanPath.hasPrefix("$..") {
            let pathAfterPrefix = String(cleanPath.dropFirst(3))
            let parts = pathAfterPrefix.split(separator: ".").map(String.init)
            if let first = parts.first {
                let deepNodes = deepFind(key: first, in: root)
                if parts.count > 1 {
                    let remaining = Array(parts.dropFirst())
                    let subExtracted = deepNodes.flatMap { extract(current: $0, segments: remaining) }
                    if !subExtracted.isEmpty {
                        return subExtracted
                    }
                } else if !deepNodes.isEmpty {
                    return deepNodes.compactMap { "\($0)" }
                }
            }
        }

        if cleanPath.hasPrefix("$.") {
            cleanPath = String(cleanPath.dropFirst(2))
        } else if cleanPath.hasPrefix("$") {
            cleanPath = String(cleanPath.dropFirst(1))
        }

        let segments = cleanPath.split(separator: ".").map(String.init)
        return extract(current: root, segments: segments)
    }

    private static func extractLeafValues(_ current: Any) -> [String] {
        if let stringVal = current as? String {
            return [stringVal]
        } else if let numVal = current as? NSNumber {
            return [numVal.stringValue]
        } else if let arrayVal = current as? [Any] {
            return arrayVal.compactMap { "\($0)" }
        }
        return []
    }

    private static func resolveArray(key: String, from current: Any) -> [Any]? {
        if key.isEmpty {
            return current as? [Any]
        } else if let dict = current as? [String: Any] {
            return dict[key] as? [Any]
        }
        return nil
    }

    private static func parseSubscript(_ segment: String) -> (key: String, index: Int?)? {
        guard let openBracket = segment.firstIndex(of: "["),
              let closeBracket = segment.firstIndex(of: "]"),
              openBracket < closeBracket else {
            return nil
        }
        let key = String(segment[..<openBracket])
        let inner = String(segment[segment.index(after: openBracket) ..< closeBracket])
        if inner == "*" {
            return (key, nil)
        }
        return (key, Int(inner))
    }

    private static func extract(current: Any, segments: [String]) -> [String] {
        guard let first = segments.first else {
            return extractLeafValues(current)
        }

        let remaining = Array(segments.dropFirst())

        if let (key, index) = parseSubscript(first) {
            guard let items = resolveArray(key: key, from: current) else { return [] }
            if let idx = index {
                guard idx >= 0, idx < items.count else { return [] }
                return extract(current: items[idx], segments: remaining)
            }
            return items.flatMap { extract(current: $0, segments: remaining) }
        }

        if let dict = current as? [String: Any], let nextNode = dict[first] {
            return extract(current: nextNode, segments: remaining)
        }

        return []
    }

    /// 从 JSON 中提取对象数组（用于列表行解析）
    public static func parseArray(json: String, path: String) -> [Any]? {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("||") {
            let candidates = trimmed.components(separatedBy: "||")
            for candidate in candidates {
                if let res = parseSingleArray(root: root, path: candidate), !res.isEmpty {
                    return res
                }
            }
            return nil
        }

        if trimmed.contains("&&") {
            let parts = trimmed.components(separatedBy: "&&")
            var combined: [Any] = []
            for part in parts {
                if let sub = parseSingleArray(root: root, path: part) {
                    combined.append(contentsOf: sub)
                }
            }
            return combined.isEmpty ? nil : combined
        }

        return parseSingleArray(root: root, path: trimmed)
    }

    private static func parseSingleArray(root: Any, path: String) -> [Any]? {
        var cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPath.lowercased().hasPrefix("@json:") {
            cleanPath = String(cleanPath.dropFirst(6))
        }

        // 深度递归检索 $..field
        if cleanPath.hasPrefix("$..") {
            let pathAfterPrefix = String(cleanPath.dropFirst(3))
            let parts = pathAfterPrefix.split(separator: ".").map(String.init)
            if let first = parts.first {
                let deepNodes = deepFind(key: first, in: root)
                if parts.count > 1 {
                    let remaining = Array(parts.dropFirst())
                    let subExtracted = deepNodes
                        .compactMap { extractObjects(current: $0, segments: remaining) }
                        .flatMap { $0 }
                    if !subExtracted.isEmpty {
                        return subExtracted
                    }
                } else if !deepNodes.isEmpty {
                    return deepNodes
                }
            }
        }

        if cleanPath.hasPrefix("$.") {
            cleanPath = String(cleanPath.dropFirst(2))
        } else if cleanPath.hasPrefix("$") {
            cleanPath = String(cleanPath.dropFirst(1))
        }

        let segments = cleanPath.split(separator: ".").map(String.init)
        return extractObjects(current: root, segments: segments)
    }

    private static func extractObjects(current: Any, segments: [String]) -> [Any]? {
        guard let first = segments.first else {
            return (current as? [Any]) ?? [current]
        }

        let remaining = Array(segments.dropFirst())

        if let (key, index) = parseSubscript(first) {
            guard let items = resolveArray(key: key, from: current) else { return nil }
            if let idx = index {
                guard idx >= 0, idx < items.count else { return nil }
                let target = items[idx]
                if remaining.isEmpty {
                    return (target as? [Any]) ?? [target]
                }
                return extractObjects(current: target, segments: remaining)
            }
            if remaining.isEmpty {
                return items
            }
            return items.compactMap { extractObjects(current: $0, segments: remaining) }.flatMap { $0 }
        }

        if let dict = current as? [String: Any], let nextNode = dict[first] {
            return extractObjects(current: nextNode, segments: remaining)
        }

        return nil
    }

    public static func deepFind(key: String, in node: Any) -> [Any] {
        var cleanKey = key
        var targetIndex: Int?
        if let parsed = parseSubscript(key) {
            cleanKey = parsed.key
            targetIndex = parsed.index
        }

        var results: [Any] = []
        if let dict = node as? [String: Any] {
            for (dictKey, val) in dict {
                if dictKey == cleanKey {
                    if let arr = val as? [Any] {
                        if let targetIndex, targetIndex >= 0, targetIndex < arr.count {
                            results.append(arr[targetIndex])
                        } else {
                            results.append(contentsOf: arr)
                        }
                    } else {
                        results.append(val)
                    }
                } else {
                    results.append(contentsOf: deepFind(key: key, in: val))
                }
            }
        } else if let arr = node as? [Any] {
            for item in arr {
                results.append(contentsOf: deepFind(key: key, in: item))
            }
        }
        return results
    }
}
