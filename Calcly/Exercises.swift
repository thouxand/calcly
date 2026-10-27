import Foundation

/// What an exercise trains. Lessons mix one or more of these.
enum Skill: String, Codable, CaseIterable {
    case powerRule, powerSums, basicDerivatives
    case productRule, quotientRule
    case chainIdentify, chainLinear, chainInner
    case integralPowers, basicIntegrals, integralLinear
    case substitutionIdentify, substitution
    case byPartsRule, byParts

    var isIntegration: Bool {
        switch self {
        case .integralPowers, .basicIntegrals, .integralLinear, .substitutionIdentify, .substitution, .byPartsRule, .byParts: return true
        default: return false
        }
    }
}

struct Exercise: Identifiable {
    enum Kind {
        /// Pick one answer.
        case choice([String], correct: Int)
        /// Is the statement true?
        case trueFalse(Bool)
        /// Pairs to match; the left side belongs with the right side at the same index.
        case match([String], [String])
        /// Tap tiles in order. Any of `answers` counts as right.
        case build(tiles: [String], answers: [[String]])
    }

    let id = UUID()
    var prompt: String
    var question: String
    var kind: Kind
    /// Shown after answering: the rule and the right answer.
    var explanation: String
    var skill: Skill
}

// MARK: - Building blocks

/// A function with its derivative.
private struct F {
    let f: String
    let d: String
    /// Typical wrong derivatives.
    var mistakes: [String] = []
}

private struct Integral {
    let integrand: String
    let answer: String
    var mistakes: [String]
}

enum Generator {
    /// One exercise for `skill`. `level` 1 is gentle, 3 is hard.
    static func make(_ skill: Skill, level: Int = 1) -> Exercise {
        switch skill {
        case .powerRule: return powerRule(level: level, sums: false)
        case .powerSums: return powerRule(level: max(2, level), sums: true)
        case .basicDerivatives: return basicDerivative()
        case .productRule: return productRule()
        case .quotientRule: return quotientRule()
        case .chainIdentify: return chainIdentify()
        case .chainLinear: return chainRule(inner: linearInners())
        case .chainInner: return chainRule(inner: polynomialInners())
        case .integralPowers: return integralPower(level: level)
        case .basicIntegrals: return basicIntegral()
        case .integralLinear: return integralLinear()
        case .substitutionIdentify: return substitutionIdentify()
        case .substitution: return substitution()
        case .byPartsRule: return byPartsRule()
        case .byParts: return byParts()
        }
    }

    /// A quick true/false or three-option question, for the timed round.
    static func quick(_ skill: Skill) -> Exercise {
        var e = make(skill, level: 2)
        if case .match = e.kind { e = make(skill, level: 2) }
        if case .build = e.kind { e = make(skill, level: 2) }
        switch e.kind {
        case .choice(let options, let correct):
            var keep = [options[correct]] + options.enumerated().filter { $0.offset != correct }.map(\.element).pick(2)
            let right = keep[0]
            keep.shuffle()
            e.kind = .choice(keep, correct: keep.firstIndex(of: right) ?? 0)
            return e
        case .trueFalse:
            return e
        default:
            return make(.basicDerivatives)
        }
    }

    // MARK: Shared helpers

    private static func choice(_ prompt: String, _ question: String, correct: String, wrong: [String],
                               explanation: String, skill: Skill, count: Int = 4) -> Exercise {
        var seen: Set<String> = [correct]
        var distractors: [String] = []
        for w in wrong.shuffled() where !seen.contains(w) {
            seen.insert(w)
            distractors.append(w)
            if distractors.count == count - 1 { break }
        }
        var options = distractors + [correct]
        options.shuffle()
        return Exercise(prompt: prompt, question: question, kind: .choice(options, correct: options.firstIndex(of: correct)!),
                        explanation: explanation, skill: skill)
    }

    /// The same fact asked as a true/false statement, half the time with a wrong answer.
    private static func trueFalse(_ left: String, correct: String, wrong: [String], explanation: String, skill: Skill) -> Exercise {
        let candidates = wrong.filter { $0 != correct }
        let truth = candidates.isEmpty || Bool.random()
        let shown = truth ? correct : candidates.randomElement()!
        return Exercise(prompt: "Sandt eller falsk?", question: "\(left) = \(shown)", kind: .trueFalse(truth),
                        explanation: explanation, skill: skill)
    }

    /// Picks a format: mostly multiple choice, sometimes true/false.
    private static func ask(_ prompt: String, _ question: String, tfLeft: String, correct: String, wrong: [String],
                            explanation: String, skill: Skill) -> Exercise {
        if Int.random(in: 0..<10) < 3 {
            return trueFalse(tfLeft, correct: correct, wrong: wrong, explanation: explanation, skill: skill)
        }
        return choice(prompt, question, correct: correct, wrong: wrong, explanation: explanation, skill: skill)
    }

    private static func diff(_ f: String) -> String { "f(x) = \(f)" }

    // MARK: Power rule

    private static func powerRule(level: Int, sums: Bool) -> Exercise {
        let exps = level == 1 ? Array(2...6) : [2, 3, 4, 5, 6, 7, -1, -2, -3]
        let n = exps.randomElement()!
        let a = Q(level == 1 ? Int.random(in: 1...6) : [1, 2, 3, 4, 5, 6, 7, -2, -3].randomElement()!)
        let rule = "Potensreglen: (a·x^{n})′ = a·n·x^{n−1}"

        if !sums {
            let f = M.term(a, M.x(n))
            let d = M.term(a * Q(n), M.x(n - 1))
            var wrong = [M.term(a, M.x(n - 1)), M.term(a * Q(n), M.x(n)),
                         M.term(-(a * Q(n)), M.x(n - 1)), M.term(a * Q(n - 1), M.x(n - 1)), M.term(a * Q(n), M.x(n + 1))]
            if n != -1 { wrong.append(M.term(a / Q(n + 1), M.x(n + 1))) }    // integrated instead
            // Building the answer from tiles: coefficient and power.
            let coefficient = a * Q(n)
            if level == 1, !coefficient.isOne, Int.random(in: 0..<4) == 0 {
                let tiles = [M.number(coefficient), M.x(n - 1)]
                let extra = [M.number(a), M.x(n), M.x(n + 1), M.number(a * Q(n - 1))].filter { !tiles.contains($0) && !$0.isEmpty }
                return Exercise(prompt: "Byg f′(x)", question: diff(f),
                                kind: .build(tiles: (tiles + Array(Set(extra)).pick(3)).shuffled(), answers: [tiles]),
                                explanation: "\(rule)\nf′(x) = \(d)", skill: .powerRule)
            }
            return ask("Find f′(x)", diff(f), tfLeft: "(\(f))′", correct: d, wrong: wrong,
                       explanation: "\(rule)\nf′(x) = \(d)", skill: .powerRule)
        }

        // Sum of two powers and a constant.
        var m = exps.randomElement()!
        while m == n { m = exps.randomElement()! }
        let b = Q([1, 2, 3, 4, 5, -1, -2, -4].randomElement()!)
        let c = Q([1, 2, 3, 5, 7, 9, -4, -6].randomElement()!)
        let f = M.sum([M.term(a, M.x(n)), M.term(b, M.x(m)), M.number(c)])
        let t1 = M.term(a * Q(n), M.x(n - 1)), t2 = M.term(b * Q(m), M.x(m - 1))
        let d = M.sum([t1, t2])
        let wrong = [
            M.sum([t1, t2, M.number(c)]),
            M.sum([M.term(a, M.x(n - 1)), M.term(b, M.x(m - 1))]),
            M.sum([t1, M.term(b * Q(m), M.x(m))]),
            M.sum([M.term(a * Q(n), M.x(n)), M.term(b * Q(m), M.x(m))]),
            M.sum([t1, M.negate(t2)]),
        ]
        return ask("Find f′(x)", diff(f), tfLeft: "(\(f))′", correct: d, wrong: wrong,
                   explanation: "Differentiér led for led. Konstanten forsvinder.\n\(rule)\nf′(x) = \(d)", skill: .powerSums)
    }

    // MARK: Basic derivatives

    private static let facts: [F] = [
        F(f: "e^{x}", d: "e^{x}", mistakes: ["x·e^{x−1}", "e^{x−1}", "ln(x)"]),
        F(f: "ln(x)", d: "\\frac{1}{x}", mistakes: ["\\frac{1}{x^{2}}", "e^{x}", "x·ln(x) − x", "−\\frac{1}{x}"]),
        F(f: "sin(x)", d: "cos(x)", mistakes: ["−cos(x)", "−sin(x)", "sin(x)"]),
        F(f: "cos(x)", d: "−sin(x)", mistakes: ["sin(x)", "−cos(x)", "cos(x)"]),
        F(f: "tan(x)", d: "\\frac{1}{cos^{2}(x)}", mistakes: ["−\\frac{1}{cos^{2}(x)}", "\\frac{1}{sin^{2}(x)}", "cot(x)"]),
        F(f: "√x", d: "\\frac{1}{2√x}", mistakes: ["\\frac{1}{√x}", "2√x", "\\frac{2}{3}x√x"]),
        F(f: "\\frac{1}{x}", d: "−\\frac{1}{x^{2}}", mistakes: ["\\frac{1}{x^{2}}", "ln(x)", "−\\frac{1}{x}"]),
        F(f: "2^{x}", d: "2^{x}·ln(2)", mistakes: ["x·2^{x−1}", "2^{x}", "\\frac{2^{x}}{ln(2)}"]),
        F(f: "x", d: "1", mistakes: ["0", "x", "\\frac{1}{2}x^{2}"]),
        F(f: "7", d: "0", mistakes: ["7", "1", "7x"]),
    ]

    private static func basicDerivative() -> Exercise {
        if Int.random(in: 0..<5) == 0 {
            let four = facts.filter { $0.f != "7" }.pick(4)
            return Exercise(prompt: "Find parrene: funktion og afledt", question: "", kind: .match(four.map(\.f), four.map(\.d)),
                            explanation: four.map { "(\($0.f))′ = \($0.d)" }.joined(separator: "\n"), skill: .basicDerivatives)
        }
        let fact = facts.randomElement()!
        let others = facts.filter { $0.f != fact.f }.map(\.d).pick(2)
        return ask("Find f′(x)", diff(fact.f), tfLeft: "(\(fact.f))′", correct: fact.d, wrong: fact.mistakes + others,
                   explanation: "(\(fact.f))′ = \(fact.d)", skill: .basicDerivatives)
    }

    // MARK: Product and quotient rule

    private struct Part { let f: String; let d: String; let dNeg: Bool; let power: Int? }

    private static let polys: [Part] = [
        Part(f: "x", d: "", dNeg: false, power: 1),
        Part(f: "x^{2}", d: "2x", dNeg: false, power: 2),
        Part(f: "x^{3}", d: "3x^{2}", dNeg: false, power: 3),
    ]
    private static let transcendental: [Part] = [
        Part(f: "e^{x}", d: "e^{x}", dNeg: false, power: nil),
        Part(f: "sin(x)", d: "cos(x)", dNeg: false, power: nil),
        Part(f: "cos(x)", d: "sin(x)", dNeg: true, power: nil),
        Part(f: "ln(x)", d: "\\frac{1}{x}", dNeg: false, power: nil),
    ]

    private static func productRule() -> Exercise {
        if Int.random(in: 0..<6) == 0 {
            return choice("Hvad siger produktreglen?", "(f·g)′ = ?", correct: "f′·g + f·g′",
                          wrong: ["f′·g′", "f′·g − f·g′", "f·g′ − f′·g", "(f′·g + f·g′)·g"],
                          explanation: "Produktreglen: (f·g)′ = f′·g + f·g′", skill: .productRule)
        }
        let p = polys.randomElement()!, t = transcendental.randomElement()!
        let f = "\(p.f)·\(t.f)"
        // f′·g: for x it is just g.
        let first = p.d.isEmpty ? t.f : "\(p.d)·\(t.f)"
        // f·g′, simplifying x^n · 1/x.
        var second: String
        if t.f == "ln(x)", let n = p.power {
            second = n == 1 ? "1" : M.x(n - 1)
        } else {
            second = "\(p.f)·\(t.d)"
        }
        if t.dNeg { second = M.minus + second }
        let d = M.sum([first, second])
        let gPrimeOnly = t.dNeg ? M.minus + (p.d.isEmpty ? t.d : "\(p.d)·\(t.d)") : (p.d.isEmpty ? t.d : "\(p.d)·\(t.d)")
        let wrong = [gPrimeOnly, first, second, M.sum([first, M.negate(second)])]
        let explanation = "Produktreglen: (f·g)′ = f′·g + f·g′\nf = \(p.f), g = \(t.f)\nf′(x) = \(d)"
        if !t.dNeg, Int.random(in: 0..<4) == 0 {
            var tiles: [String] = []
            for t in [first, "+", second, M.minus, gPrimeOnly] where !tiles.contains(t) { tiles.append(t) }
            return Exercise(prompt: "Byg f′(x)", question: diff(f),
                            kind: .build(tiles: tiles.shuffled(), answers: [[first, "+", second], [second, "+", first]]),
                            explanation: explanation, skill: .productRule)
        }
        return ask("Find f′(x)", diff(f), tfLeft: "(\(f))′", correct: d, wrong: wrong, explanation: explanation, skill: .productRule)
    }

    private static let quotients: [(String, String, [String])] = [
        ("\\frac{sin(x)}{x}", "\\frac{x·cos(x) − sin(x)}{x^{2}}", ["\\frac{sin(x) − x·cos(x)}{x^{2}}", "\\frac{x·cos(x) + sin(x)}{x^{2}}", "cos(x)"]),
        ("\\frac{e^{x}}{x}", "\\frac{e^{x}(x − 1)}{x^{2}}", ["\\frac{e^{x}(1 − x)}{x^{2}}", "\\frac{e^{x}(x + 1)}{x^{2}}", "e^{x}"]),
        ("\\frac{x}{x + 1}", "\\frac{1}{(x + 1)^{2}}", ["−\\frac{1}{(x + 1)^{2}}", "\\frac{2x + 1}{(x + 1)^{2}}", "1"]),
        ("\\frac{ln(x)}{x}", "\\frac{1 − ln(x)}{x^{2}}", ["\\frac{ln(x) − 1}{x^{2}}", "\\frac{1}{x^{2}}", "\\frac{1 + ln(x)}{x^{2}}"]),
        ("\\frac{x^{2}}{x + 1}", "\\frac{x^{2} + 2x}{(x + 1)^{2}}", ["\\frac{x^{2} − 2x}{(x + 1)^{2}}", "2x", "\\frac{3x^{2} + 2x}{(x + 1)^{2}}"]),
        ("\\frac{1}{x^{2} + 1}", "−\\frac{2x}{(x^{2} + 1)^{2}}", ["\\frac{2x}{(x^{2} + 1)^{2}}", "\\frac{1}{2x}", "−\\frac{1}{(x^{2} + 1)^{2}}"]),
        ("\\frac{sin(x)}{cos(x)}", "\\frac{1}{cos^{2}(x)}", ["−\\frac{1}{cos^{2}(x)}", "−\\frac{cos(x)}{sin(x)}", "\\frac{1}{sin^{2}(x)}"]),
        ("\\frac{x}{e^{x}}", "\\frac{1 − x}{e^{x}}", ["\\frac{x − 1}{e^{x}}", "\\frac{1 + x}{e^{x}}", "\\frac{1}{e^{x}}"]),
    ]

    private static func quotientRule() -> Exercise {
        let rule = "Kvotientreglen: (\\frac{f}{g})′ = \\frac{f′·g − f·g′}{g^{2}}"
        if Int.random(in: 0..<5) == 0 {
            return choice("Hvad siger kvotientreglen?", "(\\frac{f}{g})′ = ?", correct: "\\frac{f′·g − f·g′}{g^{2}}",
                          wrong: ["\\frac{f′·g + f·g′}{g^{2}}", "\\frac{f·g′ − f′·g}{g^{2}}", "\\frac{f′}{g′}", "\\frac{f′·g − f·g′}{g}"],
                          explanation: rule, skill: .quotientRule)
        }
        let (f, d, wrong) = quotients.randomElement()!
        return ask("Find f′(x)", diff(f), tfLeft: "(\(f))′", correct: d, wrong: wrong,
                   explanation: "\(rule)\nf′(x) = \(d)", skill: .quotientRule)
    }

    // MARK: Chain rule

    /// Inner function u with u′ = coef · body.
    private struct Inner { let u: String; let coef: Q; let body: String; let linear: Bool }

    private static func linearInners() -> Inner {
        let k = Int.random(in: 2...6)
        let b = [0, 0, 1, 2, 3, 5, -1, -4].randomElement()!
        let u = M.sum([M.term(Q(k), "x"), b == 0 ? "" : M.number(Q(b))])
        return Inner(u: u, coef: Q(k), body: "", linear: b == 0)
    }

    private static func polynomialInners() -> Inner {
        [
            Inner(u: "x^{2}", coef: Q(2), body: "x", linear: false),
            Inner(u: "x^{3}", coef: Q(3), body: "x^{2}", linear: false),
            Inner(u: "x^{2} + 1", coef: Q(2), body: "x", linear: false),
            Inner(u: "x^{3} + 2", coef: Q(3), body: "x^{2}", linear: false),
            Inner(u: "3x^{2} + 1", coef: Q(6), body: "x", linear: false),
            Inner(u: "x^{2} − 3x", coef: Q(1), body: "(2x − 3)", linear: false),
            Inner(u: "sin(x)", coef: Q(1), body: "cos(x)", linear: false),
        ].randomElement()!
    }

    private enum Outer: CaseIterable { case sin, cos, exp, ln, pow, sqrt }

    /// Outer functions that make a sensible exercise with this inner one: no (x^{2})^{3} or ln(x^{3}).
    private static func outers(for inner: Inner) -> [Outer] {
        if inner.u == "sin(x)" { return [.exp, .pow] }
        if inner.u == "x^{2}" || inner.u == "x^{3}" { return [.sin, .cos, .exp] }
        return Outer.allCases
    }

    /// u written inside the outer function.
    private static func apply(_ o: Outer, _ u: String, n: Int = 3) -> String {
        switch o {
        case .sin: return "sin(\(u))"
        case .cos: return "cos(\(u))"
        case .exp: return "e^{\(u)}"
        case .ln: return "ln(\(u))"
        case .pow: return "(\(u))^{\(n)}"
        case .sqrt: return "√(\(u))"
        }
    }

    /// coef·body·rest written neatly: "6x·cos(x^{2})", "−3sin(3x)".
    private static func product(_ c: Q, _ body: String, _ rest: String) -> String {
        let core = [body, rest].filter { !$0.isEmpty }.joined(separator: body.isEmpty || rest.isEmpty ? "" : "·")
        return M.term(c, core)
    }

    private static func chainRule(inner: Inner) -> Exercise {
        if Int.random(in: 0..<7) == 0 {
            return choice("Hvad siger kædereglen?", "(f(g(x)))′ = ?", correct: "f′(g(x))·g′(x)",
                          wrong: ["f′(g′(x))", "f′(x)·g′(x)", "f(g′(x))·g′(x)", "f′(g(x)) + g′(x)"],
                          explanation: "Kædereglen: ydre afledt (med den indre urørt) gange indre afledt.\n(f(g(x)))′ = f′(g(x))·g′(x)",
                          skill: inner.linear ? .chainLinear : .chainInner)
        }
        let skill: Skill = inner.body.isEmpty ? .chainLinear : .chainInner
        let n = Int.random(in: 2...5)
        let outers = outers(for: inner)
        let o = outers.randomElement()!
        let f = apply(o, inner.u, n: n)
        let du = M.term(inner.coef, inner.body)
        // u′ written inside another function without double brackets: sin(2x − 3), not sin((2x − 3)).
        let duIn = du.hasPrefix("(") && du.hasSuffix(")") ? String(du.dropFirst().dropLast()) : du
        var d: String
        var wrong: [String] = []
        switch o {
        case .sin:
            d = product(inner.coef, inner.body, "cos(\(inner.u))")
            wrong = ["cos(\(inner.u))", M.negate(d), product(inner.coef, inner.body, "sin(\(inner.u))"), "cos(\(duIn))"]
        case .cos:
            d = product(-inner.coef, inner.body, "sin(\(inner.u))")
            wrong = ["−sin(\(inner.u))", M.negate(d), product(inner.coef, inner.body, "cos(\(inner.u))"), "−sin(\(duIn))"]
        case .exp:
            d = product(inner.coef, inner.body, "e^{\(inner.u)}")
            wrong = ["e^{\(inner.u)}", "e^{\(du)}", product(inner.coef, inner.body, "e^{\(du)}"),
                     "(\(inner.u))·e^{\(inner.u)}"]
        case .ln:
            if inner.linear {
                d = "\\frac{1}{x}"
                wrong = ["\\frac{1}{\(inner.u)}", M.frac(M.number(inner.coef), "x"), "\\frac{\(inner.u)}{x}", "ln(\(M.number(inner.coef)))"]
            } else {
                d = M.frac(du, inner.u)
                wrong = [M.frac("1", inner.u), M.frac(inner.u, du), M.frac("1", du), "ln(\(duIn))"]
            }
        case .pow:
            let exponent = n - 1 == 1 ? "(\(inner.u))" : "(\(inner.u))^{\(n - 1)}"
            d = product(inner.coef * Q(n), inner.body, exponent)
            wrong = [M.term(Q(n), exponent), product(inner.coef * Q(n), inner.body, "(\(inner.u))^{\(n)}"),
                     product(inner.coef, inner.body, exponent), M.term(Q(n), "(\(du))^{\(n - 1)}")]
        case .sqrt:
            // u′ / (2√u), with an even coefficient reduced.
            let half = inner.coef / Q(2)
            if half.q == 1 {
                d = M.frac(M.term(half, inner.body).isEmpty ? "1" : M.term(half, inner.body), "√(\(inner.u))")
            } else {
                d = M.frac(du, "2√(\(inner.u))")
            }
            wrong = [M.frac("1", "2√(\(inner.u))"), M.frac(du, "√(\(inner.u))"), "2√(\(inner.u))·\(du)", M.frac("1", "2√(\(duIn))")]
        }
        let outerName: String
        switch o {
        case .sin: outerName = "sin(u)"
        case .cos: outerName = "cos(u)"
        case .exp: outerName = "e^{u}"
        case .ln: outerName = "ln(u)"
        case .pow: outerName = "u^{\(n)}"
        case .sqrt: outerName = "√u"
        }
        let explanation = "Kædereglen: ydre afledt · indre afledt.\nIndre: u = \(inner.u), u′ = \(du)\nYdre: \(outerName)\nf′(x) = \(d)"
        return ask("Find f′(x)", diff(f), tfLeft: "(\(f))′", correct: d, wrong: wrong, explanation: explanation, skill: skill)
    }

    private static func chainIdentify() -> Exercise {
        let inner = Bool.random() ? linearInners() : polynomialInners()
        let outers = outers(for: inner)
        let o = outers.randomElement()!
        let n = Int.random(in: 2...5)
        let f = apply(o, inner.u, n: n)
        let outerX = apply(o, "x", n: n).replacingOccurrences(of: "(x)^{", with: "x^{").replacingOccurrences(of: "√(x)", with: "√x")
        let du = M.term(inner.coef, inner.body)
        if Bool.random() {
            return choice("Hvad er den indre funktion?", diff(f), correct: inner.u, wrong: [outerX, du, "x", f],
                          explanation: "Den indre funktion er det, der står inde i den ydre: u = \(inner.u)", skill: .chainIdentify)
        }
        return choice("Hvad er den ydre funktion?", diff(f), correct: outerX, wrong: [inner.u, du, apply(o, du, n: n), "x"],
                      explanation: "Den ydre funktion er den, der virker på det hele: \(outerX), med u = \(inner.u) indeni.",
                      skill: .chainIdentify)
    }

    // MARK: Integration

    private static func integral(_ s: String) -> String { "∫ \(s) dx" }
    private static func plusC(_ s: String) -> String { s + " + C" }

    private static func integralPower(level: Int) -> Exercise {
        let n = (level == 1 ? [0, 1, 2, 3, 4, 5] : [1, 2, 3, 4, 5, 6, -2, -3]).randomElement()!
        let a = Q([1, 2, 3, 4, 5, 6, 8, 10, 12].randomElement()!)
        let f = M.term(a, M.x(n))
        let answer = plusC(M.term(a / Q(n + 1), M.x(n + 1)))
        var wrong = [plusC(M.term(a, M.x(n + 1))), plusC(M.term(a * Q(n), M.x(n - 1))),
                     plusC(M.term(a / Q(n + 1), M.x(n))), M.term(a / Q(n + 1), M.x(n + 1))]
        if n != 0 { wrong.append(plusC(M.term(a / Q(n), M.x(n + 1)))) }
        let rule = "∫ x^{n} dx = \\frac{1}{n + 1}x^{n+1} + C  (n ≠ −1)"
        if n == 0 {
            return ask("Find stamfunktionen", integral(M.number(a)), tfLeft: integral(M.number(a)), correct: plusC(M.term(a, "x")),
                       wrong: [plusC("0"), M.term(a, "x"), plusC(M.term(a / Q(2), "x^{2}")), plusC(M.number(a))],
                       explanation: "En konstant integreres til konstanten gange x.\n∫ \(M.number(a)) dx = \(plusC(M.term(a, "x")))",
                       skill: .integralPowers)
        }
        return ask("Find stamfunktionen", integral(f), tfLeft: integral(f), correct: answer, wrong: wrong,
                   explanation: "\(rule)\nHusk + C.\n\(integral(f)) = \(answer)", skill: .integralPowers)
    }

    private static let integralFacts: [Integral] = [
        Integral(integrand: "e^{x}", answer: "e^{x} + C", mistakes: ["x·e^{x} + C", "\\frac{e^{x+1}}{x + 1} + C", "e^{x}·ln(x) + C"]),
        Integral(integrand: "\\frac{1}{x}", answer: "ln|x| + C", mistakes: ["−\\frac{1}{x^{2}} + C", "\\frac{1}{x^{2}} + C", "x·ln(x) + C"]),
        Integral(integrand: "sin(x)", answer: "−cos(x) + C", mistakes: ["cos(x) + C", "−sin(x) + C", "sin(x) + C"]),
        Integral(integrand: "cos(x)", answer: "sin(x) + C", mistakes: ["−sin(x) + C", "cos(x) + C", "−cos(x) + C"]),
        Integral(integrand: "\\frac{1}{cos^{2}(x)}", answer: "tan(x) + C", mistakes: ["−tan(x) + C", "\\frac{1}{sin^{2}(x)} + C", "ln|cos(x)| + C"]),
        Integral(integrand: "√x", answer: "\\frac{2}{3}x√x + C", mistakes: ["\\frac{1}{2√x} + C", "\\frac{3}{2}x√x + C", "x√x + C"]),
        Integral(integrand: "\\frac{1}{x^{2}}", answer: "−\\frac{1}{x} + C", mistakes: ["\\frac{1}{x} + C", "ln(x^{2}) + C", "−\\frac{2}{x^{3}} + C"]),
    ]

    private static func basicIntegral() -> Exercise {
        if Int.random(in: 0..<5) == 0 {
            let four = integralFacts.pick(4)
            return Exercise(prompt: "Find parrene: funktion og stamfunktion", question: "",
                            kind: .match(four.map(\.integrand), four.map(\.answer)),
                            explanation: four.map { "\(integral($0.integrand)) = \($0.answer)" }.joined(separator: "\n"),
                            skill: .basicIntegrals)
        }
        let fact = integralFacts.randomElement()!
        let others = integralFacts.filter { $0.answer != fact.answer }.map(\.answer).pick(2)
        return ask("Find stamfunktionen", integral(fact.integrand), tfLeft: integral(fact.integrand), correct: fact.answer,
                   wrong: fact.mistakes + others, explanation: "\(integral(fact.integrand)) = \(fact.answer)", skill: .basicIntegrals)
    }

    private static func integralLinear() -> Exercise {
        let k = Int.random(in: 2...6)
        let u = "\(k)x"
        let inv = Q(1, k)
        let rule = "Med kx indeni skal du dividere med k (kædereglen baglæns)."
        switch Int.random(in: 0..<3) {
        case 0:
            let ans = plusC(M.term(inv, "e^{\(u)}"))
            return ask("Find stamfunktionen", integral("e^{\(u)}"), tfLeft: integral("e^{\(u)}"), correct: ans,
                       wrong: [plusC("e^{\(u)}"), plusC(M.term(Q(k), "e^{\(u)}")), plusC(M.term(inv, "e^{x}")), plusC("x·e^{\(u)}")],
                       explanation: "\(rule)\n∫ e^{kx} dx = \\frac{1}{k}e^{kx} + C\n= \(ans)", skill: .integralLinear)
        case 1:
            let ans = plusC(M.term(-inv, "cos(\(u))"))
            return ask("Find stamfunktionen", integral("sin(\(u))"), tfLeft: integral("sin(\(u))"), correct: ans,
                       wrong: [plusC(M.term(inv, "cos(\(u))")), plusC("−cos(\(u))"), plusC(M.term(Q(-k), "cos(\(u))")), plusC(M.term(inv, "sin(\(u))"))],
                       explanation: "\(rule)\n∫ sin(kx) dx = −\\frac{1}{k}cos(kx) + C\n= \(ans)", skill: .integralLinear)
        default:
            let ans = plusC(M.term(inv, "sin(\(u))"))
            return ask("Find stamfunktionen", integral("cos(\(u))"), tfLeft: integral("cos(\(u))"), correct: ans,
                       wrong: [plusC("sin(\(u))"), plusC(M.term(-inv, "sin(\(u))")), plusC(M.term(Q(k), "sin(\(u))")), plusC(M.term(inv, "cos(\(u))"))],
                       explanation: "\(rule)\n∫ cos(kx) dx = \\frac{1}{k}sin(kx) + C\n= \(ans)", skill: .integralLinear)
        }
    }

    // MARK: Substitution

    private struct SubInner { let u: String; let coef: Q; let body: String; let positive: Bool }

    private static let subInners: [SubInner] = [
        SubInner(u: "x^{2}", coef: Q(2), body: "x", positive: false),
        SubInner(u: "x^{3}", coef: Q(3), body: "x^{2}", positive: false),
        SubInner(u: "x^{2} + 1", coef: Q(2), body: "x", positive: true),
        SubInner(u: "x^{3} + 2", coef: Q(3), body: "x^{2}", positive: false),
        SubInner(u: "x^{2} + 4", coef: Q(2), body: "x", positive: true),
        SubInner(u: "sin(x)", coef: Q(1), body: "cos(x)", positive: false),
    ]

    private enum SubOuter: CaseIterable { case cos, sin, exp, pow, recip }

    private static func substitution() -> Exercise {
        let inner = subInners.randomElement()!
        var outers = SubOuter.allCases
        if !inner.positive { outers.removeAll { $0 == .recip } }
        if inner.u == "x^{2}" || inner.u == "x^{3}" { outers.removeAll { $0 == .pow } }
        let o = outers.randomElement()!
        let n = Int.random(in: 2...4)
        // Sometimes the integrand has only part of u′ (x instead of 2x), so a factor appears.
        let m: Q = Bool.random() ? inner.coef : Q(1)
        let factor = m / inner.coef
        let u = inner.u
        let integrand: String
        // Antiderivative G and a typical wrong one, each as coefficient · body.
        let G: (Q, String), W: (Q, String)
        switch o {
        case .cos:
            integrand = product(m, inner.body, "cos(\(u))")
            G = (Q(1), "sin(\(u))"); W = (Q(-1), "sin(\(u))")
        case .sin:
            integrand = product(m, inner.body, "sin(\(u))")
            G = (Q(-1), "cos(\(u))"); W = (Q(1), "cos(\(u))")
        case .exp:
            integrand = product(m, inner.body, "e^{\(u)}")
            G = (Q(1), "e^{\(u)}"); W = (Q(1), "(\(u))·e^{\(u)}")
        case .pow:
            integrand = product(m, inner.body, "(\(u))^{\(n)}")
            G = (Q(1, n + 1), "(\(u))^{\(n + 1)}"); W = (Q(1, n), "(\(u))^{\(n)}")
        case .recip:
            integrand = M.frac(M.term(m, inner.body), u)
            G = (Q(1), "ln(\(u))"); W = (Q(1), "\\frac{1}{(\(u))^{2}}")
        }
        let answer = plusC(M.term(factor * G.0, G.1))
        let wrong = [plusC(M.term(G.0, G.1)), plusC(M.term(factor * W.0, W.1)), plusC(M.term(m * G.0, G.1)),
                     plusC(product(m, inner.body, M.term(G.0, G.1))), plusC(M.term(inner.coef * G.0, G.1))]
        let explanation = "Sæt u = \(u), så du = \(M.term(inner.coef, inner.body)) dx.\n\(integral(integrand)) = \(answer)"
        return ask("Find stamfunktionen", integral(integrand), tfLeft: integral(integrand), correct: answer, wrong: wrong,
                   explanation: explanation, skill: .substitution)
    }

    private static func substitutionIdentify() -> Exercise {
        let inner = subInners.randomElement()!
        var choices = ["cos(\(inner.u))", "e^{\(inner.u)}"]
        if inner.u != "x^{2}" && inner.u != "x^{3}" { choices.append("(\(inner.u))^{3}") }
        let outer = choices.randomElement()!
        let integrand = product(inner.coef, inner.body, outer)
        let du = M.term(inner.coef, inner.body)
        return choice("Hvad skal u være?", integral(integrand), correct: "u = \(inner.u)",
                      wrong: ["u = \(du)", "u = \(outer)", "u = x", "u = \(integrand)"],
                      explanation: "Vælg u som den indre funktion, hvis afledte (\(du)) også står i integralet.", skill: .substitutionIdentify)
    }

    // MARK: Integration by parts

    private static let byPartsFormula = "∫ f·g′ dx = f·g − ∫ f′·g dx"

    private static func byPartsRule() -> Exercise {
        if Bool.random() {
            return choice("Hvad siger formlen for delvis integration?", "∫ f·g′ dx = ?", correct: "f·g − ∫ f′·g dx",
                          wrong: ["f·g + ∫ f′·g dx", "f′·g − ∫ f·g′ dx", "f·g′ − ∫ f′·g dx", "f′·g′ − ∫ f·g dx"],
                          explanation: "Delvis integration: \(byPartsFormula)\nVælg f, så den bliver enklere, når du differentierer.",
                          skill: .byPartsRule)
        }
        let cases: [(String, String, String)] = [
            ("x·e^{x}", "x", "e^{x}"), ("x·sin(x)", "x", "sin(x)"), ("x·cos(x)", "x", "cos(x)"),
            ("x^{2}·e^{x}", "x^{2}", "e^{x}"), ("x·ln(x)", "ln(x)", "x"), ("ln(x)", "ln(x)", "1"),
        ]
        let (integrand, f, g) = cases.randomElement()!
        return choice("Hvilken faktor skal du differentiere (f)?", integral(integrand), correct: f,
                      wrong: [g, "dx", "begge"].filter { $0 != f },
                      explanation: "Vælg f som den, der bliver enklere ved differentiation. ln(x) og potenser af x er gode valg; e^{x}, sin og cos er nemme at integrere.",
                      skill: .byPartsRule, count: 3)
    }

    private static let byPartsCases: [Integral] = [
        Integral(integrand: "x·e^{x}", answer: "(x − 1)e^{x} + C", mistakes: ["(x + 1)e^{x} + C", "x·e^{x} + C", "\\frac{1}{2}x^{2}e^{x} + C"]),
        Integral(integrand: "x·sin(x)", answer: "sin(x) − x·cos(x) + C", mistakes: ["x·cos(x) − sin(x) + C", "−x·cos(x) − sin(x) + C", "\\frac{1}{2}x^{2}sin(x) + C"]),
        Integral(integrand: "x·cos(x)", answer: "x·sin(x) + cos(x) + C", mistakes: ["x·sin(x) − cos(x) + C", "−x·sin(x) + cos(x) + C", "\\frac{1}{2}x^{2}cos(x) + C"]),
        Integral(integrand: "ln(x)", answer: "x·ln(x) − x + C", mistakes: ["\\frac{1}{x} + C", "x·ln(x) + x + C", "(ln(x))^{2} + C"]),
        Integral(integrand: "x·ln(x)", answer: "\\frac{1}{2}x^{2}ln(x) − \\frac{1}{4}x^{2} + C", mistakes: ["\\frac{1}{2}x^{2}ln(x) + C", "x·ln(x) − x + C", "\\frac{1}{2}x^{2}ln(x) + \\frac{1}{4}x^{2} + C"]),
        Integral(integrand: "x^{2}·e^{x}", answer: "(x^{2} − 2x + 2)e^{x} + C", mistakes: ["(x^{2} + 2x + 2)e^{x} + C", "x^{2}e^{x} − 2x·e^{x} + C", "\\frac{1}{3}x^{3}e^{x} + C"]),
        Integral(integrand: "x·e^{2x}", answer: "\\frac{1}{2}x·e^{2x} − \\frac{1}{4}e^{2x} + C", mistakes: ["\\frac{1}{2}x·e^{2x} + \\frac{1}{4}e^{2x} + C", "x·e^{2x} − e^{2x} + C", "2x·e^{2x} − 4e^{2x} + C"]),
    ]

    private static func byParts() -> Exercise {
        let c = byPartsCases.randomElement()!
        return ask("Find stamfunktionen", integral(c.integrand), tfLeft: integral(c.integrand), correct: c.answer,
                   wrong: c.mistakes, explanation: "Delvis integration: \(byPartsFormula)\n\(integral(c.integrand)) = \(c.answer)",
                   skill: .byParts)
    }
}
