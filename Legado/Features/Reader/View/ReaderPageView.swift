import SwiftUI

/// 单页排版内容呈现视图
public struct ReaderPageView: View {
    let page: ReaderPage
    let totalPages: Int
    let config: ReaderConfig

    public init(
        page: ReaderPage,
        totalPages: Int,
        config: ReaderConfig) {
        self.page = page
        self.totalPages = totalPages
        self.config = config
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 页顶：章节标题与状态微标
            HStack {
                Text(page.chapterTitle)
                    .font(.caption2)
                    .foregroundStyle(config.theme.textColor.opacity(0.45))
                    .lineLimit(1)

                Spacer()

                // 当前时间简报
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(config.theme.textColor.opacity(0.45))
            }
            .padding(.horizontal, config.horizontalMargin)
            .padding(.top, 10)
            .frame(height: config.topMargin, alignment: .bottom)

            // 正文区域
            Text(page.contentText)
                .font(.system(size: config.fontSize))
                .lineSpacing(config.lineSpacing)
                .foregroundStyle(config.theme.textColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, config.horizontalMargin)
                .padding(.top, 8)

            // 页脚：页码比率与全书进度
            HStack {
                Text("第 \(page.pageIndex + 1) / \(max(totalPages, 1)) 页")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(config.theme.textColor.opacity(0.45))

                Spacer()
            }
            .padding(.horizontal, config.horizontalMargin)
            .padding(.bottom, 12)
            .frame(height: config.bottomMargin, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(config.theme.backgroundColor)
        .ignoresSafeArea()
    }
}
