import SwiftUI

extension BookSourceEditView {

    // MARK: - 基本信息

    var baseSection: some View {
        VStack(spacing: 14) {
            inputField(
                label: "书源名称",
                hint: "例如: 笔趣阁",
                key: "bookSourceName",
                isRequired: true)

            inputField(
                label: "书源主页 URL",
                hint: "https://www.example.com",
                key: "bookSourceUrl",
                isRequired: true)

            inputField(
                label: "书源分组",
                hint: "多个分组以逗号隔开，如: 优质, 小说",
                key: "bookSourceGroup")

            inputField(
                label: "书源注释",
                hint: "书源维护者、说明或备忘",
                key: "bookSourceComment",
                isMultiline: true)

            inputField(
                label: "书籍详情页正则 Pattern",
                hint: "用于在浏览器拦截时自动识别详情页",
                key: "bookUrlPattern")

            inputField(
                label: "自定义请求头 Header",
                hint: "JSON 格式: {\"User-Agent\": \"...\"}",
                key: "header",
                isMultiline: true)

            inputField(
                label: "登录 URL",
                hint: "登录页面地址",
                key: "loginUrl")

            // 开关组与类型
            VStack(spacing: 12) {
                HStack {
                    Text("书源类型")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { viewModel.state.source.bookSourceType ?? 0 },
                        set: { viewModel.send(.updateSourceType($0)) })) {
                            Text("文本小说").tag(0)
                            Text("有声听书").tag(1)
                            Text("漫画图文").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                }

                Divider().opacity(0.4)

                Toggle("启用此书源", isOn: Binding(
                    get: { viewModel.state.source.enabled ?? true },
                    set: { viewModel.send(.toggleBoolean(key: "enabled", value: $0)) }))

                Toggle("启用发现模块", isOn: Binding(
                    get: { viewModel.state.source.enabledExplore ?? true },
                    set: { viewModel.send(.toggleBoolean(key: "enabledExplore", value: $0)) }))
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    // MARK: - 搜索规则

    var searchSection: some View {
        VStack(spacing: 14) {
            inputField(
                label: "搜索地址 Search URL",
                hint: "/search?key={{key}}&page={{page}}",
                key: "searchUrl",
                isMultiline: true)

            inputField(
                label: "校验关键字 CheckKeyWord",
                hint: "用于探测源连通性的特征关键词",
                key: "ruleSearch.checkKeyWord")

            inputField(
                label: "书籍列表规则 BookList",
                hint: "class.item 或 $.data.list[*]",
                key: "ruleSearch.bookList")

            inputField(label: "书名 Name", hint: "tag.a.0@text", key: "ruleSearch.name")
            inputField(label: "作者 Author", hint: "class.author@text", key: "ruleSearch.author")
            inputField(label: "分类 Kind", hint: "class.tag@text", key: "ruleSearch.kind")
            inputField(label: "字数 WordCount", hint: "class.words@text", key: "ruleSearch.wordCount")
            inputField(label: "最新章节 LastChapter", hint: "class.last@text", key: "ruleSearch.lastChapter")
            inputField(label: "简介 Intro", hint: "class.desc@text", key: "ruleSearch.intro", isMultiline: true)
            inputField(label: "封面 CoverUrl", hint: "tag.img@src", key: "ruleSearch.coverUrl")
            inputField(label: "书籍详情地址 BookUrl", hint: "tag.a.0@href", key: "ruleSearch.bookUrl")
        }
    }

    // MARK: - 发现规则

    var exploreSection: some View {
        VStack(spacing: 14) {
            inputField(
                label: "发现地址 Explore URL",
                hint: "支持分类格式: 玄幻小说::/sort/1\n都市小说::/sort/2",
                key: "exploreUrl",
                isMultiline: true)

            inputField(label: "书籍列表规则 BookList", hint: "class.book-item", key: "ruleExplore.bookList")
            inputField(label: "书名 Name", hint: "tag.h3@text", key: "ruleExplore.name")
            inputField(label: "作者 Author", hint: "class.author@text", key: "ruleExplore.author")
            inputField(label: "分类 Kind", hint: "class.type@text", key: "ruleExplore.kind")
            inputField(label: "字数 WordCount", hint: "class.words@text", key: "ruleExplore.wordCount")
            inputField(label: "最新章节 LastChapter", hint: "class.chapter@text", key: "ruleExplore.lastChapter")
            inputField(label: "简介 Intro", hint: "class.intro@text", key: "ruleExplore.intro", isMultiline: true)
            inputField(label: "封面 CoverUrl", hint: "tag.img@src", key: "ruleExplore.coverUrl")
            inputField(label: "书籍详情地址 BookUrl", hint: "tag.a@href", key: "ruleExplore.bookUrl")
        }
    }

    // MARK: - 详情信息规则

    var infoSection: some View {
        VStack(spacing: 14) {
            inputField(label: "预处理规则 Init", hint: "@json: 或 JS 脚本提前处理", key: "ruleBookInfo.init")
            inputField(label: "书名 Name", hint: "class.title@text", key: "ruleBookInfo.name")
            inputField(label: "作者 Author", hint: "class.writer@text", key: "ruleBookInfo.author")
            inputField(label: "分类 Kind", hint: "class.tags@text", key: "ruleBookInfo.kind")
            inputField(label: "字数 WordCount", hint: "class.size@text", key: "ruleBookInfo.wordCount")
            inputField(label: "最新章节 LastChapter", hint: "class.latest@text", key: "ruleBookInfo.lastChapter")
            inputField(label: "简介 Intro", hint: "class.book-intro@html", key: "ruleBookInfo.intro", isMultiline: true)
            inputField(label: "封面 CoverUrl", hint: "class.book-cover@img@src", key: "ruleBookInfo.coverUrl")
            inputField(label: "目录 URL TocUrl", hint: "class.btn-toc@href (若同页面可留空)", key: "ruleBookInfo.tocUrl")
            inputField(label: "允许重命名 CanReName", hint: "true / false", key: "ruleBookInfo.canReName")
        }
    }

    // MARK: - 目录规则

    var tocSection: some View {
        VStack(spacing: 14) {
            inputField(
                label: "章节列表 ChapterList",
                hint: "class.chapter-list@tag.a 或 $.data.chapters[*]",
                key: "ruleToc.chapterList")
            inputField(label: "章节名称 ChapterName", hint: "text", key: "ruleToc.chapterName")
            inputField(label: "章节地址 ChapterUrl", hint: "href", key: "ruleToc.chapterUrl")
            inputField(label: "VIP 标识 IsVip", hint: "class.vip 或 $.is_vip", key: "ruleToc.isVip")
            inputField(label: "更新时间 UpdateTime", hint: "class.time@text", key: "ruleToc.updateTime")
            inputField(label: "下一页目录 NextTocUrl", hint: "text.下一页@href", key: "ruleToc.nextTocUrl")
        }
    }

    // MARK: - 正文规则

    var contentSection: some View {
        VStack(spacing: 14) {
            inputField(
                label: "正文内容 Content",
                hint: "id.content@textNodes 或 $.data.content",
                key: "ruleContent.content",
                isMultiline: true)

            inputField(
                label: "下一页正文 NextContentUrl",
                hint: "text.下一页@href (用于长章节分页)",
                key: "ruleContent.nextContentUrl")

            inputField(
                label: "净化正则 SourceRegex",
                hint: "##(本章完|广告.*)##",
                key: "ruleContent.sourceRegex",
                isMultiline: true)

            inputField(
                label: "动态注入脚本 WebJs",
                hint: "document.querySelector('...').click();",
                key: "ruleContent.webJs",
                isMultiline: true)
        }
    }

    // MARK: - 评语规则

    var reviewSection: some View {
        VStack(spacing: 14) {
            inputField(
                label: "评语地址 ReviewUrl",
                hint: "/comment/list?bookId={{book.bookUrl}}",
                key: "ruleReview.reviewUrl")

            inputField(
                label: "评语内容 ContentRule",
                hint: "class.comment-text@text",
                key: "ruleReview.contentRule",
                isMultiline: true)
            inputField(label: "用户头像 AvatarRule", hint: "class.avatar@img@src", key: "ruleReview.avatarRule")
            inputField(label: "发布时间 PostTimeRule", hint: "class.time@text", key: "ruleReview.postTimeRule")
        }
    }

    // MARK: - 通用输入字段卡片组件

    func inputField(
        label: String,
        hint: String,
        key: String,
        isRequired: Bool = false,
        isMultiline: Bool = false) -> some View {
        let isFocused = viewModel.state.activeFieldKey == key

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)

                if isRequired {
                    Text("*")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.red)
                }

                Spacer()

                Text(key)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if isMultiline {
                TextField(hint, text: Binding(
                    get: { viewModel.state.fieldValue(for: key) },
                    set: { viewModel.send(.updateField(key: key, value: $0)) }), axis: .vertical)
                    .lineLimit(2 ... 6)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.send(.setActiveField(key: key))
                    })
            } else {
                TextField(hint, text: Binding(
                    get: { viewModel.state.fieldValue(for: key) },
                    set: { viewModel.send(.updateField(key: key, value: $0)) }))
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.send(.setActiveField(key: key))
                    })
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? Color.blue : Color.white.opacity(0.18), lineWidth: isFocused ? 1.5 : 0.5))
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
