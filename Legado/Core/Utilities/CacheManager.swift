import Foundation

/// 跨会话与内存两级缓存管理器 (对齐 Android Legado CacheManager.kt)
public final class CacheManager: @unchecked Sendable {
    public static let shared = CacheManager()

    private let lock = NSLock()
    private var memoryCache: [String: Any] = [:]
    private var expirationMap: [String: Date] = [:]
    private let userDefaultsKey = "legado_persistent_cache_manager"

    private init() {}

    public func putMemory(_ key: String, _ value: Any) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache[key] = value
    }

    public func getFromMemory(_ key: String) -> Any? {
        lock.lock()
        defer { lock.unlock() }
        return memoryCache[key]
    }

    public func deleteMemory(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.removeValue(forKey: key)
    }

    public func put(_ key: String, _ value: Any, saveTime: Int = 0) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache[key] = value
        if saveTime > 0 {
            expirationMap[key] = Date().addingTimeInterval(TimeInterval(saveTime))
        } else {
            expirationMap.removeValue(forKey: key)
        }
        let strVal = "\(value)"
        UserDefaults.standard.set(strVal, forKey: "\(userDefaultsKey)_\(key)")
    }

    public func get(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let exp = expirationMap[key], exp < Date() {
            memoryCache.removeValue(forKey: key)
            expirationMap.removeValue(forKey: key)
            UserDefaults.standard.removeObject(forKey: "\(userDefaultsKey)_\(key)")
            return nil
        }
        if let memVal = memoryCache[key] {
            return "\(memVal)"
        }
        if let saved = UserDefaults.standard.string(forKey: "\(userDefaultsKey)_\(key)") {
            memoryCache[key] = saved
            return saved
        }
        return nil
    }

    public func delete(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.removeValue(forKey: key)
        expirationMap.removeValue(forKey: key)
        UserDefaults.standard.removeObject(forKey: "\(userDefaultsKey)_\(key)")
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.removeAll()
        expirationMap.removeAll()
    }
}
