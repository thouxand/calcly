import Foundation

/// f(x) written in plain syntax: "6x^2 − 3", "3cos(3x)", "sqrt(x)", "e^(2x)", "ln(x)", "|x|".
struct Expression {
    fileprivate indirect enum Node {
        case number(Double)
        case x
        case negate(Node)
        case binary(Character, Node, Node)
        case function(String, Node)
    }

    private let root: Node

    init?(_ text: String) {
        guard let tokens = Tokenizer.tokens(text) else { return nil }
        var parser = Parser(tokens: tokens)
        guard let node = parser.parse() else { return nil }
        root = node
    }

    func value(at x: Double) -> Double { Self.eval(root, x) }

    private static func eval(_ n: Node, _ x: Double) -> Double {
        switch n {
        case .number(let v): return v
        case .x: return x
        case .negate(let a): return -eval(a, x)
        case .binary(let op, let a, let b):
            let l = eval(a, x), r = eval(b, x)
            switch op {
            case "+": return l + r
            case "-": return l - r
            case "*": return l * r
            case "/": return l / r
            default: return pow(l, r)
            }
        case .function(let name, let a):
            let v = eval(a, x)
            switch name {
            case "sin": return sin(v)
            case "cos": return cos(v)
            case "tan": return tan(v)
            case "sqrt": return sqrt(v)
            case "ln": return log(v)
            case "log": return log10(v)
            case "exp": return exp(v)
            default: return abs(v)
            }
        }
    }

    fileprivate enum Token: Equatable {
        case number(Double), x, constant(Double), function(String), symbol(Character)
    }

    private enum Tokenizer {
        static let functions = ["sqrt", "sin", "cos", "tan", "exp", "abs", "log", "ln"]

        static func tokens(_ raw: String) -> [Token]? {
            var s = raw.lowercased()
            for (a, b) in [("·", "*"), ("×", "*"), ("÷", "/"), ("−", "-"), ("–", "-"), ("π", "pi"), ("²", "^2"), ("³", "^3"), ("√", "sqrt")] {
                s = s.replacingOccurrences(of: a, with: b)
            }
            if let eq = s.firstIndex(of: "=") { s = String(s[s.index(after: eq)...]) }
            let chars = Array(s)
            var out: [Token] = []
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if c == " " { i += 1; continue }
                if c.isNumber || c == "." || c == "," {
                    var j = i, text = ""
                    while j < chars.count, chars[j].isNumber || chars[j] == "." || chars[j] == "," {
                        text.append(chars[j] == "," ? "." : chars[j]); j += 1
                    }
                    guard let v = Double(text) else { return nil }
                    out.append(.number(v)); i = j; continue
                }
                if c.isLetter {
                    let rest = String(chars[i...])
                    if let f = functions.first(where: { rest.hasPrefix($0) }) { out.append(.function(f)); i += f.count; continue }
                    if rest.hasPrefix("pi") { out.append(.constant(.pi)); i += 2; continue }
                    if c == "x" { out.append(.x); i += 1; continue }
                    if c == "e" { out.append(.constant(M_E)); i += 1; continue }
                    return nil
                }
                if "+-*/^()|".contains(c) { out.append(.symbol(c)); i += 1; continue }
                return nil
            }
            return out.isEmpty ? nil : out
        }
    }

    private struct Parser {
        let tokens: [Token]
        var i = 0

        mutating func parse() -> Node? {
            guard let n = expression(), i == tokens.count else { return nil }
            return n
        }

        private var peek: Token? { i < tokens.count ? tokens[i] : nil }

        private mutating func expression() -> Node? {
            guard var left = term() else { return nil }
            while case .symbol(let c)? = peek, c == "+" || c == "-" {
                i += 1
                guard let right = term() else { return nil }
                left = .binary(c, left, right)
            }
            return left
        }

        private mutating func term() -> Node? {
            guard var left = unary() else { return nil }
            while let t = peek {
                if case .symbol(let c) = t, c == "*" || c == "/" {
                    i += 1
                    guard let right = unary() else { return nil }
                    left = .binary(c, left, right)
                } else if startsAtom(t) {
                    guard let right = power() else { return nil }
                    left = .binary("*", left, right)
                } else {
                    break
                }
            }
            return left
        }

        private func startsAtom(_ t: Token) -> Bool {
            switch t {
            case .number, .x, .constant, .function: return true
            case .symbol(let c): return c == "("
            }
        }

        private mutating func unary() -> Node? {
            if case .symbol(let c)? = peek, c == "-" || c == "+" {
                i += 1
                guard let n = unary() else { return nil }
                return c == "-" ? .negate(n) : n
            }
            return power()
        }

        private mutating func power() -> Node? {
            guard let base = atom() else { return nil }
            if case .symbol("^")? = peek {
                i += 1
                guard let exponent = unary() else { return nil }
                return .binary("^", base, exponent)
            }
            return base
        }

        private mutating func atom() -> Node? {
            guard let t = peek else { return nil }
            i += 1
            switch t {
            case .number(let v): return .number(v)
            case .constant(let v): return .number(v)
            case .x: return .x
            case .function(let f):
                guard let arg = power() else { return nil }
                return .function(f, arg)
            case .symbol("("):
                guard let n = expression(), case .symbol(")")? = peek else { return nil }
                i += 1
                return n
            case .symbol("|"):
                guard let n = expression(), case .symbol("|")? = peek else { return nil }
                i += 1
                return .function("abs", n)
            default:
                return nil
            }
        }
    }
}

/// Checks typed answers and turns markup into something that can be evaluated.
enum Evaluator {
    /// Markup ("3x^{2}·cos(x^{3}) + C", "\frac{1}{2}e^{2x}") as plain syntax, without "+ C".
    static func plain(_ markup: String) -> String {
        var s = markup
        if s.hasSuffix(" + C") { s.removeLast(4) }
        // sin^{2}(x) means (sin(x))^2.
        for f in ["sin", "cos", "tan"] {
            while let r = s.range(of: "\(f)^{") {
                guard let close = s[r.upperBound...].firstIndex(of: "}"),
                      s.index(after: close) < s.endIndex, s[s.index(after: close)] == "(",
                      let argEnd = s[s.index(after: close)...].firstIndex(of: ")") else { break }
                let power = s[r.upperBound..<close]
                let arg = s[s.index(after: close)...argEnd]
                s.replaceSubrange(r.lowerBound...argEnd, with: "(\(f)\(arg))^(\(power))")
            }
        }
        // \frac{a}{b} → ((a)/(b)), innermost first.
        while let r = s.range(of: "\\frac{") {
            guard let (a, afterA) = group(in: s, from: s.index(before: r.upperBound)),
                  let (b, afterB) = group(in: s, from: afterA) else { break }
            s.replaceSubrange(r.lowerBound..<afterB, with: "((\(a))/(\(b)))")
        }
        s = s.replacingOccurrences(of: "^{", with: "^(").replacingOccurrences(of: "}", with: ")")
        s = s.replacingOccurrences(of: "√x", with: "sqrt(x)").replacingOccurrences(of: "√(", with: "sqrt(")
        return s.replacingOccurrences(of: "·", with: "*").replacingOccurrences(of: "−", with: "-")
    }

    /// Reads "{…}" at `start`; returns its contents and the index after it.
    private static func group(in s: String, from start: String.Index) -> (String, String.Index)? {
        guard start < s.endIndex, s[start] == "{" else { return nil }
        var depth = 0
        var i = start
        while i < s.endIndex {
            if s[i] == "{" { depth += 1 }
            if s[i] == "}" { depth -= 1; if depth == 0 { return (String(s[s.index(after: start)..<i]), s.index(after: i)) } }
            i = s.index(after: i)
        }
        return nil
    }

    private static let samples: [Double] = [0.31, 0.67, 1.13, 1.58, 2.21, 2.87]

    /// True when the markup can be evaluated, so it can be asked as a typed answer.
    static func canEvaluate(_ markup: String) -> Bool {
        guard let e = Expression(plain(markup)) else { return false }
        return samples.filter { e.value(at: $0).isFinite }.count >= 4
    }

    /// Does `typed` mean the same as `answer`? For antiderivatives any constant is fine.
    static func equivalent(_ typed: String, _ answer: String, upToConstant: Bool) -> Bool {
        guard let a = Expression(typed), let b = Expression(plain(answer)) else { return false }
        var diffs: [Double] = []
        for x in samples {
            let u = a.value(at: x), v = b.value(at: x)
            guard u.isFinite, v.isFinite else { continue }
            diffs.append(u - v)
            if !upToConstant && abs(u - v) > 1e-6 * (1 + abs(v)) { return false }
        }
        guard diffs.count >= 3, let first = diffs.first else { return false }
        return !upToConstant || diffs.allSatisfy { abs($0 - first) < 1e-6 * (1 + abs(first)) }
    }

    // MARK: Math keyboard

    /// Keys as typed into the answer field.
    static func plain(keys: [String]) -> String {
        keys.joined().replacingOccurrences(of: "√(", with: "sqrt(").replacingOccurrences(of: "·", with: "*")
            .replacingOccurrences(of: "−", with: "-")
    }

    /// What the typed keys look like as markup: "x^2" shows as x², "e^(2x)" as e²ˣ.
    static func display(keys raw: [String]) -> String {
        let keys = raw.flatMap { $0 == "e^" ? ["e", "^"] : [$0] }
        var out = ""
        var i = 0
        while i < keys.count {
            let k = keys[i]
            if k == "^", i + 1 < keys.count {
                // Exponent: a bracket group, or a run of digits / x.
                var j = i + 1
                var exponent = ""
                if keys[j] == "(" {
                    var depth = 0
                    while j < keys.count {
                        if keys[j].hasSuffix("(") { depth += 1 }
                        if keys[j] == ")" { depth -= 1 }
                        exponent += keys[j]
                        j += 1
                        if depth == 0 { break }
                    }
                    if exponent.hasPrefix("("), exponent.hasSuffix(")") { exponent = String(exponent.dropFirst().dropLast()) }
                } else {
                    while j < keys.count, keys[j].allSatisfy({ $0.isNumber || $0 == "x" || $0 == "," || $0 == "−" }) {
                        if keys[j] == "−" && j > i + 1 { break }
                        exponent += keys[j]
                        j += 1
                    }
                }
                out += exponent.isEmpty ? "^" : "^{\(exponent)}"
                i = j
                continue
            }
            out += k == "*" ? "·" : k
            i += 1
        }
        return out
    }
}
