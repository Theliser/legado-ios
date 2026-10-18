import Foundation

/// 删除书架分组用例
public final class DeleteBookGroupUseCase: Sendable {
    private let groupRepository: BookGroupRepository

    public init(groupRepository: BookGroupRepository) {
        self.groupRepository = groupRepository
    }

    public func execute(id: String) async throws {
        try await groupRepository.deleteGroup(id: id)
    }
}
