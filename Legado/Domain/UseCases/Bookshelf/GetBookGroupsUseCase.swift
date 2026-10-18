import Foundation

/// 获取书架自定义分组用例
public final class GetBookGroupsUseCase: Sendable {
    private let groupRepository: BookGroupRepository

    public init(groupRepository: BookGroupRepository) {
        self.groupRepository = groupRepository
    }

    public func execute() async throws -> [BookGroup] {
        try await groupRepository.getGroups()
    }
}
