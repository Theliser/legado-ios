import Foundation

/// 书架自定义分组仓储协议
public protocol BookGroupRepository: Sendable {
    func getGroups() async throws -> [BookGroup]
    func saveGroup(_ group: BookGroup) async throws
    func deleteGroup(id: String) async throws
}
