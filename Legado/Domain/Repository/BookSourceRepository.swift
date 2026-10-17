import Foundation

/// 书源持久化仓储协议
public protocol BookSourceRepository: Sendable {
    /// 获取所有本地已保存书源
    func fetchSources() async throws -> [BookSource]

    /// 获取已启用的有效书源
    func fetchEnabledSources() async throws -> [BookSource]

    /// 批量保存或更新书源
    func saveSources(_ sources: [BookSource]) async throws

    /// 单个保存或更新书源
    func updateSource(_ source: BookSource) async throws

    /// 删除指定 URL 的书源
    func deleteSource(url: String) async throws

    /// 清空所有书源
    func clearSources() async throws
}
