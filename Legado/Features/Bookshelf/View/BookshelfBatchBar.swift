import SwiftUI

/// 书架批量操作悬浮控制栏 (Liquid Glass 材质)
public struct BookshelfBatchBar: View {
    public let selectedCount: Int
    public let isAllSelected: Bool
    public let customGroups: [BookGroup]
    public let onToggleSelectAll: () -> Void
    public let onBatchMove: (String?) -> Void
    public let onBatchRemove: () -> Void
    public let onFinish: () -> Void

    public init(
        selectedCount: Int,
        isAllSelected: Bool,
        customGroups: [BookGroup],
        onToggleSelectAll: @escaping () -> Void,
        onBatchMove: @escaping (String?) -> Void,
        onBatchRemove: @escaping () -> Void,
        onFinish: @escaping () -> Void) {
        self.selectedCount = selectedCount
        self.isAllSelected = isAllSelected
        self.customGroups = customGroups
        self.onToggleSelectAll = onToggleSelectAll
        self.onBatchMove = onBatchMove
        self.onBatchRemove = onBatchRemove
        self.onFinish = onFinish
    }

    public var body: some View {
        GlassFloatingBar {
            HStack(spacing: 16) {
                // 全选 / 取消全选
                Button(action: onToggleSelectAll) {
                    VStack(spacing: 2) {
                        Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .medium))
                        Text(isAllSelected ? "取消全选" : "全选")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.plain)

                // 已选数量
                Text("已选 \(selectedCount) 本")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // 移动分组菜单
                Menu {
                    Button("移出分组") {
                        onBatchMove(nil)
                    }
                    ForEach(customGroups) { group in
                        Button(group.name) {
                            onBatchMove(group.name)
                        }
                    }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(.system(size: 16, weight: .medium))
                        Text("分组")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)

                // 批量移出
                Button(role: .destructive, action: onBatchRemove) {
                    VStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selectedCount > 0 ? Color.red : Color.secondary)
                        Text("移出")
                            .font(.system(size: 10))
                            .foregroundStyle(selectedCount > 0 ? Color.red : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(selectedCount == 0)

                Divider()
                    .frame(height: 20)

                // 完成退出批量模式
                Button(action: onFinish) {
                    Text("完成")
                        .font(.footnote.bold())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
