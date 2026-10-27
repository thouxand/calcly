import Foundation

// Maths is written as small markup strings:
//   x^{3}            superscript
//   \frac{1}{2}      fraction
// Everything else is shown as text. `MathText` draws it.

/// An exact fraction, so coefficients like ⅓ stay exact.
struct Q: Equatable, Hashable {
    let p: Int
    let q: Int

    init(_ p: Int, _ q: Int = 1) {
        precondition(q != 0)
        let g = Q.gcd(Swift.abs(p), Swift.abs(q))
        let s = q < 0 ? -1 : 1
        self.p = s * p / max(g, 1)
        self.q = s * q / max(g, 1)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? max(a, 1) : gcd(b, a % b) }

    static func * (a: Q, b: Q) -> Q { Q(a.p * b.p, a.q * b.q) }
    static func / (a: Q, b: Q) -> Q { Q(a.p * b.q, a.q * b.p) }
    static func + (a: Q, b: Q) -> Q { Q(a.p * b.q + b.p * a.q, a.q * b.q) }
    static prefix func - (a: Q) -> Q { Q(-a.p, a.q) }

    var isZero: Bool { p == 0 }
    var isOne: Bool { p == 1 && q == 1 }
    var isMinusOne: Bool { p == -1 && q == 1 }
    var isNegative: Bool { p < 0 }
    var abs: Q { Q(Swift.abs(p), q) }
}

enum M {
    static let minus = "−"

    /// 3, −2, \frac{1}{3}, −\frac{2}{5}
    static func number(_ c: Q) -> String {
        let sign = c.isNegative ? minus : ""
        let a = c.abs
        return a.q == 1 ? "\(sign)\(a.p)" : "\(sign)\\frac{\(a.p)}{\(a.q)}"
    }

    /// x, x^{3}, x^{−2}, or "" for x⁰.
    static func x(_ n: Int) -> String {
        switch n {
        case 0: return ""
        case 1: return "x"
        default: return "x^{\(n < 0 ? minus + String(-n) : String(n))}"
        }
    }

    /// Coefficient times a body: 3x^{2}, −sin(x), \frac{1}{2}e^{2x}, 5.
    static func term(_ c: Q, _ body: String) -> String {
        if body.isEmpty { return number(c) }
        if c.isOne { return body }
        if c.isMinusOne { return minus + body }
        return number(c) + body
    }

    /// Joins terms with + and −, dropping zeros: "3x^{2} − 2x + 1".
    static func sum(_ terms: [String]) -> String {
        var out = ""
        for t in terms where !t.isEmpty && t != "0" {
            if out.isEmpty {
                out = t
            } else if t.hasPrefix(minus) {
                out += " \(minus) " + t.dropFirst()
            } else {
                out += " + " + t
            }
        }
        return out.isEmpty ? "0" : out
    }

    /// Flips the sign of a term.
    static func negate(_ t: String) -> String {
        t.hasPrefix(minus) ? String(t.dropFirst()) : (t == "0" ? t : minus + t)
    }

    static func frac(_ a: String, _ b: String) -> String { "\\frac{\(a)}{\(b)}" }
}

extension Array {
    /// A few random elements, without repeats.
    func pick(_ n: Int) -> [Element] { Array(shuffled().prefix(n)) }
}
