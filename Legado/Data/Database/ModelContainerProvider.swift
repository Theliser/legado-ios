import Foundation
import SwiftData

/// SwiftData 容器配置与提供者
public final class ModelContainerProvider: @unchecked Sendable {
    public static let shared = ModelContainerProvider()

    public let container: ModelContainer

    public init(inMemory: Bool = false) {
        let schema = Schema([
            BookSourceEntity.self,
            BookEntity.self,
            ChapterEntity.self,
            ReadRecordEntity.self,
            BookmarkEntity.self,
        ])

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory)

        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }

    /// 创建一个独立的上下文 (适用于后台任务或主线程)
    @MainActor
    public var mainContext: ModelContext {
        container.mainContext
    }

    /// 创建一个后台模型上下文
    public func newBackgroundContext() -> ModelContext {
        ModelContext(container)
    }
}
