import Foundation

/// 规则变量存储接口 (对齐 Android Legado RuleDataInterface)
public protocol RuleDataInterface: AnyObject, Sendable {
    var variableMap: [String: String] { get set }
    func putVariable(_ key: String, _ value: String?) -> Bool
    func putBigVariable(_ key: String, _ value: String?)
    func getVariable(_ key: String) -> String
    func getBigVariable(_ key: String) -> String?
}

public extension RuleDataInterface {
    func putVariable(_ key: String, _ value: String?) -> Bool {
        let keyExist = variableMap[key] != nil
        if let value {
            if value.count < 10000 {
                putBigVariable(key, nil)
                variableMap[key] = value
                return true
            } else {
                variableMap.removeValue(forKey: key)
                putBigVariable(key, value)
                return keyExist
            }
        } else {
            variableMap.removeValue(forKey: key)
            putBigVariable(key, nil)
            return keyExist
        }
    }

    func getVariable(_ key: String) -> String {
        variableMap[key] ?? getBigVariable(key) ?? ""
    }

    func putBigVariable(_: String, _: String?) {}
    func getBigVariable(_: String) -> String? {
        nil
    }
}

/// 默认通用规则变量存储实现 (对齐 Android Legado RuleData)
public final class RuleData: RuleDataInterface, @unchecked Sendable {
    private let lock = NSLock()
    private var _variableMap: [String: String] = [:]

    public var variableMap: [String: String] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _variableMap
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _variableMap = newValue
        }
    }

    public init(variables: [String: String] = [:]) {
        self._variableMap = variables
    }

    public func putVariable(_ key: String, _ value: String?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let keyExist = _variableMap[key] != nil
        if let value {
            _variableMap[key] = value
            return true
        } else {
            _variableMap.removeValue(forKey: key)
            return keyExist
        }
    }

    public func getVariable(_ key: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return _variableMap[key] ?? ""
    }

    public func putBigVariable(_ key: String, _ value: String?) {
        _ = putVariable(key, value)
    }

    public func getBigVariable(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return _variableMap[key]
    }

    public func getVariable() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !_variableMap.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: _variableMap, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
