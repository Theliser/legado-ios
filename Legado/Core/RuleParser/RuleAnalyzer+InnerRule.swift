import Foundation

// MARK: - Inner Rule Interpolation Extension (对齐 Android Legado innerRule)

public extension RuleAnalyzer {
    func innerRule(
        _ inner: String,
        startStep: Int = 1,
        endStep: Int = 1,
        evaluator: (String) -> String?) -> String {
        var resultBuilder = ""
        while consumeTo(inner) {
            let posPre = pos
            if chompCodeBalanced(open: "{", close: "}") {
                let innerContent = substring(posPre + startStep, pos - endStep)
                if let evaluated = evaluator(innerContent), !evaluated.isEmpty {
                    resultBuilder += substring(startX, posPre) + evaluated
                    startX = pos
                    continue
                }
            }
            pos += inner.count
        }
        if startX == 0 {
            return ""
        }
        resultBuilder += substring(startX)
        return resultBuilder
    }

    func innerRule(
        _ startStr: String,
        _ endStr: String,
        evaluator: (String) -> String?) -> String {
        var resultBuilder = ""
        while consumeTo(startStr) {
            pos += startStr.count
            let posPre = pos
            if consumeTo(endStr) {
                let evaluated = evaluator(substring(posPre, pos)) ?? ""
                resultBuilder += substring(startX, posPre - startStr.count) + evaluated
                pos += endStr.count
                startX = pos
            }
        }
        if startX == 0 {
            return String(chars)
        }
        resultBuilder += substring(startX)
        return resultBuilder
    }
}
