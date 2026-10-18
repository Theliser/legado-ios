import Foundation

/// 纯正则提取引擎 (对齐 Android Legado AnalyzeByRegex)
public enum AnalyzeByRegex {
    /// 递归匹配多段正则，最后一项提取所有捕获组 (groupValues)
    public static func getElement(res: String, regs: [String], index: Int = 0) -> [String]? {
        guard index < regs.count else { return nil }
        let pattern = regs[index]
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = res as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: res, options: [], range: fullRange) else {
            return nil
        }

        if index + 1 == regs.count {
            var info: [String] = []
            for groupIdx in 0 ..< match.numberOfRanges {
                let rangeAtGroup = match.range(at: groupIdx)
                if rangeAtGroup.location != NSNotFound {
                    info.append(nsString.substring(with: rangeAtGroup))
                } else {
                    info.append("")
                }
            }
            return info
        } else {
            var combined = ""
            let matches = regex.matches(in: res, options: [], range: fullRange)
            for singleMatch in matches where singleMatch.range.location != NSNotFound {
                combined += nsString.substring(with: singleMatch.range)
            }
            return getElement(res: combined, regs: regs, index: index + 1)
        }
    }

    /// 递归匹配多段正则，最后一项提取所有匹配项的捕获组矩阵
    public static func getElements(res: String, regs: [String], index: Int = 0) -> [[String]] {
        guard index < regs.count else { return [] }
        let pattern = regs[index]
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = res as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: res, options: [], range: fullRange)
        guard !matches.isEmpty else { return [] }

        if index + 1 == regs.count {
            var results: [[String]] = []
            for singleMatch in matches {
                var info: [String] = []
                for groupIdx in 0 ..< singleMatch.numberOfRanges {
                    let rangeAtGroup = singleMatch.range(at: groupIdx)
                    if rangeAtGroup.location != NSNotFound {
                        info.append(nsString.substring(with: rangeAtGroup))
                    } else {
                        info.append("")
                    }
                }
                results.append(info)
            }
            return results
        } else {
            var combined = ""
            for singleMatch in matches where singleMatch.range.location != NSNotFound {
                combined += nsString.substring(with: singleMatch.range)
            }
            return getElements(res: combined, regs: regs, index: index + 1)
        }
    }
}
