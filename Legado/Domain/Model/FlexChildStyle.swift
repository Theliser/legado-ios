import Foundation

/// 弹性子视图布局样式 (对齐 Android Legado FlexChildStyle.kt)
public struct FlexChildStyle: Codable, Equatable, Sendable {
    public var layoutFlexGrow: Float
    public var layoutFlexShrink: Float
    public var layoutAlignSelf: String
    public var layoutFlexBasisPercent: Float
    public var layoutWrapBefore: Bool
    public var layoutJustifySelf: String

    public init(
        layoutFlexGrow: Float = 0.0,
        layoutFlexShrink: Float = 1.0,
        layoutAlignSelf: String = "auto",
        layoutFlexBasisPercent: Float = -1.0,
        layoutWrapBefore: Bool = false,
        layoutJustifySelf: String = "auto") {
        self.layoutFlexGrow = layoutFlexGrow
        self.layoutFlexShrink = layoutFlexShrink
        self.layoutAlignSelf = layoutAlignSelf
        self.layoutFlexBasisPercent = layoutFlexBasisPercent
        self.layoutWrapBefore = layoutWrapBefore
        self.layoutJustifySelf = layoutJustifySelf
    }

    private enum CodingKeys: String, CodingKey {
        case layoutFlexGrow = "layout_flexGrow"
        case layoutFlexShrink = "layout_flexShrink"
        case layoutAlignSelf = "layout_alignSelf"
        case layoutFlexBasisPercent = "layout_flexBasisPercent"
        case layoutWrapBefore = "layout_wrapBefore"
        case layoutJustifySelf = "layout_justifySelf"
    }

    public static let defaultStyle = FlexChildStyle()
}
