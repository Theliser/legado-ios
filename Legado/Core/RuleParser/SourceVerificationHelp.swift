import Foundation

/// 书源反爬验证与人机挑战辅助类 (对齐 Android Legado io.legado.app.help.source.SourceVerificationHelp.kt)
public final class SourceVerificationHelp: @unchecked Sendable {
    public static let shared = SourceVerificationHelp()

    private let lock = NSLock()
    private var verificationResults: [String: (url: String, result: String)] = [:]

    private init() {}

    private func getVerificationResultKey(_ sourceKey: String) -> String {
        "\(sourceKey)_verificationResult"
    }

    public static func getResult(sourceKey: String) -> (url: String, result: String)? {
        shared.getResult(sourceKey: sourceKey)
    }

    public static func setResult(sourceKey: String, result: String, url: String = "") {
        shared.setResult(sourceKey: sourceKey, result: result, url: url)
    }

    public static func clearResult(sourceKey: String) {
        shared.clearResult(sourceKey: sourceKey)
    }

    /// 获取验证结果缓存
    public func getResult(sourceKey: String) -> (url: String, result: String)? {
        lock.lock()
        defer { lock.unlock() }
        return verificationResults[getVerificationResultKey(sourceKey)]
    }

    /// 设置验证结果
    public func setResult(sourceKey: String, result: String, url: String = "") {
        lock.lock()
        defer { lock.unlock() }
        verificationResults[getVerificationResultKey(sourceKey)] = (url, result)
    }

    /// 清空验证结果
    public func clearResult(sourceKey: String) {
        lock.lock()
        defer { lock.unlock() }
        verificationResults.removeValue(forKey: getVerificationResultKey(sourceKey))
    }

    /// 校验结果是否存在
    public func checkResult(sourceKey: String) {
        lock.lock()
        defer { lock.unlock() }
        if verificationResults[getVerificationResultKey(sourceKey)] == nil {
            verificationResults[getVerificationResultKey(sourceKey)] = ("", "")
        }
    }

    /// 唤起浏览器验证 (调用 BrowserVerificationManager)
    public func getVerificationResult(
        source: BaseSource?,
        url: String,
        title _: String,
        useBrowser _: Bool = true) async throws -> (url: String, result: String) {
        guard let source else {
            throw NSError(
                domain: "SourceVerificationHelp",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "书源不能为空"])
        }

        clearResult(sourceKey: source.getKey())

        let result = try await BrowserVerificationManager.shared.executeHeadlessWeb(
            url: url,
            webJs: nil,
            delayTimeMs: 0,
            headers: [:])

        setResult(sourceKey: source.getKey(), result: result.body, url: result.url)
        return (result.url, result.body)
    }
}
