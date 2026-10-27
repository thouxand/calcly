import Foundation

/// Parsed maths markup: text, superscripts (^{…}), subscripts (_{…}) and fractions (\frac{…}{…}).
indirect enum MathToken: Equatable {
    case text(String)
    case sup([MathToken])
    case sub([MathToken])
    case frac([MathToken], [MathToken])

    static func parse(_ s: String) -> [MathToken] {
        var out: [MathToken] = []
        var text = ""
        let chars = Array(s)
        var i = 0

        func flush() { if !text.isEmpty { out.append(.text(text)); text = "" } }

        /// Reads "{…}" starting at `i`, honouring nested braces.
        func group() -> String? {
            guard i < chars.count, chars[i] == "{" else { return nil }
            var depth = 0
            var j = i
            while j < chars.count {
                if chars[j] == "{" { depth += 1 }
                if chars[j] == "}" { depth -= 1; if depth == 0 { break } }
                j += 1
            }
            guard j < chars.count else { return nil }
            let inner = String(chars[(i + 1)..<j])
            i = j + 1
            return inner
        }

        while i < chars.count {
            if chars[i] == "^", i + 1 < chars.count, chars[i + 1] == "{" {
                i += 1
                if let g = group() { flush(); out.append(.sup(parse(g))); continue }
                text.append("^")
                continue
            }
            if chars[i] == "_", i + 1 < chars.count, chars[i + 1] == "{" {
                i += 1
                if let g = group() { flush(); out.append(.sub(parse(g))); continue }
                text.append("_")
                continue
            }
            if chars[i] == "\\", i + 5 < chars.count, String(chars[i...(i + 5)]) == "\\frac{" {
                let start = i
                i += 5
                if let a = group(), let b = group() {
                    flush()
                    out.append(.frac(parse(a), parse(b)))
                    continue
                }
                i = start + 1
                text.append("\\")
                continue
            }
            text.append(chars[i])
            i += 1
        }
        flush()
        return out
    }

    var hasFraction: Bool {
        if case .frac = self { return true }
        return false
    }
}
