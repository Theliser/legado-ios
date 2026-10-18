import Foundation

/// 保存或更新书架分组用例
public final class SaveBookGroupUseCase: Sendable {
    private let groupRepository: BookGroupRepository

    public init(groupRepository: BookGroupRepository) {
        self.groupRepository = groupRepository
    }

    public func execute(_ group: BookGroup) async throws {
        let cleanName = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        var toSave = group
        toSave.name = cleanName
        try await groupRepository.saveGroup(toSave)
    }
}
