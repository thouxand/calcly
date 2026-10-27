import Foundation

struct Lesson: Identifiable, Hashable {
    let id: String
    let title: String
    let skills: [Skill]
    /// The rule in short, shown under "Tips".
    let tip: String
    var level = 1
}

struct CourseUnit: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let colorHex: String
    let symbol: String
    let lessons: [Lesson]
}

/// A card for "Regelkort": a rule to know by heart.
struct RuleCard: Identifiable, Hashable {
    let id: String
    let front: String
    let back: String
    let group: String
}

enum Course {
    static let exercisesPerLesson = 10

    static let units: [CourseUnit] = [
        CourseUnit(id: "diff", title: "Differentiation", subtitle: "Grundreglerne", colorHex: "#3B82F6", symbol: "function", lessons: [
            Lesson(id: "diff.power", title: "Potensreglen", skills: [.powerRule],
                   tip: "(x^{n})′ = n·x^{n−1}\nKonstanten foran bliver stående:\n(a·x^{n})′ = a·n·x^{n−1}"),
            Lesson(id: "diff.basic", title: "Standardfunktioner", skills: [.basicDerivatives],
                   tip: "(e^{x})′ = e^{x}\n(ln(x))′ = \\frac{1}{x}\n(sin(x))′ = cos(x)\n(cos(x))′ = −sin(x)\n(√x)′ = \\frac{1}{2√x}"),
            Lesson(id: "diff.sums", title: "Summer og konstanter", skills: [.powerSums],
                   tip: "Differentiér led for led.\n(f + g)′ = f′ + g′\nEn konstant differentieres til 0.", level: 2),
            Lesson(id: "diff.mix", title: "Blandet", skills: [.powerRule, .powerSums, .basicDerivatives],
                   tip: "Alle grundregler blandet.", level: 2),
        ]),
        CourseUnit(id: "prod", title: "Produkt og kvotient", subtitle: "Når funktioner ganges og deles", colorHex: "#8B5CF6", symbol: "multiply", lessons: [
            Lesson(id: "prod.product", title: "Produktreglen", skills: [.productRule],
                   tip: "(f·g)′ = f′·g + f·g′\nDifferentiér den ene ad gangen, og læg sammen."),
            Lesson(id: "prod.quotient", title: "Kvotientreglen", skills: [.quotientRule],
                   tip: "(\\frac{f}{g})′ = \\frac{f′·g − f·g′}{g^{2}}\nHusk: minus, og f′ kommer først."),
            Lesson(id: "prod.mix", title: "Blandet", skills: [.productRule, .quotientRule, .basicDerivatives],
                   tip: "Produkt, kvotient og standardfunktioner.", level: 2),
        ]),
        CourseUnit(id: "chain", title: "Kædereglen", subtitle: "En funktion inden i en anden", colorHex: "#F97316", symbol: "link", lessons: [
            Lesson(id: "chain.identify", title: "Indre og ydre", skills: [.chainIdentify],
                   tip: "I f(g(x)) er g den indre funktion og f den ydre.\nEks.: sin(x^{2}) har indre x^{2} og ydre sin."),
            Lesson(id: "chain.linear", title: "Kædereglen I", skills: [.chainLinear],
                   tip: "(f(g(x)))′ = f′(g(x))·g′(x)\nMed kx indeni: gang med k.\n(sin(3x))′ = 3cos(3x)"),
            Lesson(id: "chain.inner", title: "Kædereglen II", skills: [.chainInner],
                   tip: "Ydre afledt (indre urørt) gange indre afledt.\n(e^{x^{2}})′ = 2x·e^{x^{2}}"),
            Lesson(id: "chain.mix", title: "Al differentiation", skills: [.chainLinear, .chainInner, .productRule, .quotientRule, .powerSums],
                   tip: "Find først ud af, hvilken regel der skal bruges.", level: 2),
        ]),
        CourseUnit(id: "int", title: "Integration", subtitle: "Stamfunktioner", colorHex: "#22C55E", symbol: "sum", lessons: [
            Lesson(id: "int.power", title: "Potenser", skills: [.integralPowers],
                   tip: "∫ x^{n} dx = \\frac{1}{n + 1}x^{n+1} + C  (n ≠ −1)\nLæg 1 til eksponenten, og divider med den nye."),
            Lesson(id: "int.basic", title: "Standardintegraler", skills: [.basicIntegrals],
                   tip: "∫ e^{x} dx = e^{x} + C\n∫ \\frac{1}{x} dx = ln|x| + C\n∫ sin(x) dx = −cos(x) + C\n∫ cos(x) dx = sin(x) + C"),
            Lesson(id: "int.linear", title: "kx indeni", skills: [.integralLinear],
                   tip: "Divider med k:\n∫ e^{kx} dx = \\frac{1}{k}e^{kx} + C\n∫ cos(kx) dx = \\frac{1}{k}sin(kx) + C"),
            Lesson(id: "int.mix", title: "Blandet", skills: [.integralPowers, .basicIntegrals, .integralLinear],
                   tip: "Alle grundintegraler blandet.", level: 2),
        ]),
        CourseUnit(id: "sub", title: "Substitution", subtitle: "Kædereglen baglæns", colorHex: "#EC4899", symbol: "arrow.triangle.2.circlepath", lessons: [
            Lesson(id: "sub.identify", title: "Find u", skills: [.substitutionIdentify],
                   tip: "Vælg u som den indre funktion, hvis afledte også står i integralet.\n∫ 2x·cos(x^{2}) dx: u = x^{2}, du = 2x dx"),
            Lesson(id: "sub.solve", title: "Substitution", skills: [.substitution],
                   tip: "∫ f(g(x))·g′(x) dx = F(g(x)) + C\nMangler der en faktor, så divider med den."),
        ]),
        CourseUnit(id: "parts", title: "Delvis integration", subtitle: "Produkter, der skal integreres", colorHex: "#14B8A6", symbol: "square.split.2x1", lessons: [
            Lesson(id: "parts.rule", title: "Formlen", skills: [.byPartsRule],
                   tip: "∫ f·g′ dx = f·g − ∫ f′·g dx\nVælg f, så den bliver enklere ved differentiation (ln, x^{n})."),
            Lesson(id: "parts.solve", title: "Delvis integration", skills: [.byParts, .byPartsRule],
                   tip: "∫ x·e^{x} dx: f = x, g′ = e^{x}\n= x·e^{x} − ∫ e^{x} dx = (x − 1)e^{x} + C"),
        ]),
        CourseUnit(id: "lim", title: "Grænseværdier", subtitle: "Hvad nærmer funktionen sig?", colorHex: "#06B6D4", symbol: "arrow.right.to.line", lessons: [
            Lesson(id: "lim.basic", title: "Indsæt og klassikere", skills: [.limitsBasic],
                   tip: "Er funktionen kontinuert, så sæt bare tallet ind.\nlim_{x → 0} \\frac{sin(x)}{x} = 1\nlim_{x → ∞} (1 + \\frac{1}{x})^{x} = e"),
            Lesson(id: "lim.algebra", title: "0/0 og uendelig", skills: [.limitsAlgebra],
                   tip: "Giver indsæt \\frac{0}{0}: faktorisér og forkort.\nMod ∞: kig kun på de højeste potenser i tæller og nævner."),
        ]),
        CourseUnit(id: "def", title: "Bestemte integraler", subtitle: "Areal under grafen", colorHex: "#84CC16", symbol: "chart.bar.fill", lessons: [
            Lesson(id: "def.basic", title: "Fra a til b", skills: [.definiteIntegrals],
                   tip: "∫_{a}^{b} f(x) dx = F(b) − F(a)\nFind stamfunktionen, sæt b ind, og træk F(a) fra."),
        ]),
        CourseUnit(id: "partial", title: "Partielle afledte", subtitle: "Funktioner af to variable", colorHex: "#A855F7", symbol: "cube.fill", lessons: [
            Lesson(id: "partial.basic", title: "∂f/∂x og ∂f/∂y", skills: [.partialDerivatives],
                   tip: "Differentiér efter én variabel, og behandl den anden som en konstant.\nf = x^{2}y ⇒ ∂f/∂x = 2xy, ∂f/∂y = x^{2}"),
        ]),
        CourseUnit(id: "spine", title: "Mester", subtitle: "Alt på én gang", colorHex: "#EAB308", symbol: "crown.fill", lessons: [
            Lesson(id: "spine.diff", title: "Al differentiation", skills: [.powerSums, .basicDerivatives, .productRule, .quotientRule, .chainLinear, .chainInner],
                   tip: "Potens, standard, produkt, kvotient og kæde.", level: 3),
            Lesson(id: "spine.int", title: "Al integration", skills: [.integralPowers, .basicIntegrals, .integralLinear, .substitution, .byParts],
                   tip: "Grundintegraler, kx indeni, substitution og delvis.", level: 3),
            Lesson(id: "spine.master", title: "Mesterprøven", skills: Skill.allCases,
                   tip: "Alt fra hele kurset. Klarer du den, sidder det på rygraden.", level: 3),
        ]),
    ]

    static var lessons: [Lesson] { units.flatMap(\.lessons) }

    /// Stands in for a lesson when you practise your mistakes.
    static let reviewLesson = Lesson(id: "review", title: "Øv dine fejl", skills: [.powerRule], tip: "")

    static func unit(of lesson: Lesson) -> CourseUnit? { units.first { $0.lessons.contains(lesson) } }

    /// Exercises for one lesson: a mix of its skills, no question asked twice.
    static func exercises(for lesson: Lesson, count: Int = exercisesPerLesson) -> [Exercise] {
        var out: [Exercise] = []
        var seen = Set<String>()
        var tries = 0
        while out.count < count && tries < count * 20 {
            tries += 1
            let skill = lesson.skills.randomElement()!
            let e = Generator.make(skill, level: lesson.level)
            let key = e.prompt + e.question + "\(e.kind)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(e)
        }
        return out
    }

    // MARK: Rule cards

    static let cards: [RuleCard] = [
        RuleCard(id: "d.power", front: "(x^{n})′", back: "n·x^{n−1}", group: "Differentiation"),
        RuleCard(id: "d.const", front: "(k)′  (konstant)", back: "0", group: "Differentiation"),
        RuleCard(id: "d.exp", front: "(e^{x})′", back: "e^{x}", group: "Differentiation"),
        RuleCard(id: "d.ekx", front: "(e^{kx})′", back: "k·e^{kx}", group: "Differentiation"),
        RuleCard(id: "d.ln", front: "(ln(x))′", back: "\\frac{1}{x}", group: "Differentiation"),
        RuleCard(id: "d.sin", front: "(sin(x))′", back: "cos(x)", group: "Differentiation"),
        RuleCard(id: "d.cos", front: "(cos(x))′", back: "−sin(x)", group: "Differentiation"),
        RuleCard(id: "d.tan", front: "(tan(x))′", back: "\\frac{1}{cos^{2}(x)} = 1 + tan^{2}(x)", group: "Differentiation"),
        RuleCard(id: "d.sqrt", front: "(√x)′", back: "\\frac{1}{2√x}", group: "Differentiation"),
        RuleCard(id: "d.recip", front: "(\\frac{1}{x})′", back: "−\\frac{1}{x^{2}}", group: "Differentiation"),
        RuleCard(id: "d.ax", front: "(a^{x})′", back: "a^{x}·ln(a)", group: "Differentiation"),
        RuleCard(id: "d.sum", front: "(f + g)′", back: "f′ + g′", group: "Regler"),
        RuleCard(id: "d.product", front: "Produktreglen\n(f·g)′", back: "f′·g + f·g′", group: "Regler"),
        RuleCard(id: "d.quotient", front: "Kvotientreglen\n(\\frac{f}{g})′", back: "\\frac{f′·g − f·g′}{g^{2}}", group: "Regler"),
        RuleCard(id: "d.chain", front: "Kædereglen\n(f(g(x)))′", back: "f′(g(x))·g′(x)", group: "Regler"),
        RuleCard(id: "i.power", front: "∫ x^{n} dx", back: "\\frac{1}{n + 1}x^{n+1} + C  (n ≠ −1)", group: "Integration"),
        RuleCard(id: "i.const", front: "∫ k dx", back: "kx + C", group: "Integration"),
        RuleCard(id: "i.recip", front: "∫ \\frac{1}{x} dx", back: "ln|x| + C", group: "Integration"),
        RuleCard(id: "i.exp", front: "∫ e^{x} dx", back: "e^{x} + C", group: "Integration"),
        RuleCard(id: "i.ekx", front: "∫ e^{kx} dx", back: "\\frac{1}{k}e^{kx} + C", group: "Integration"),
        RuleCard(id: "i.sin", front: "∫ sin(x) dx", back: "−cos(x) + C", group: "Integration"),
        RuleCard(id: "i.cos", front: "∫ cos(x) dx", back: "sin(x) + C", group: "Integration"),
        RuleCard(id: "i.sinkx", front: "∫ sin(kx) dx", back: "−\\frac{1}{k}cos(kx) + C", group: "Integration"),
        RuleCard(id: "i.coskx", front: "∫ cos(kx) dx", back: "\\frac{1}{k}sin(kx) + C", group: "Integration"),
        RuleCard(id: "i.sec2", front: "∫ \\frac{1}{cos^{2}(x)} dx", back: "tan(x) + C", group: "Integration"),
        RuleCard(id: "i.sqrt", front: "∫ √x dx", back: "\\frac{2}{3}x√x + C", group: "Integration"),
        RuleCard(id: "i.ln", front: "∫ ln(x) dx", back: "x·ln(x) − x + C", group: "Integration"),
        RuleCard(id: "i.sub", front: "Substitution\n∫ f(g(x))·g′(x) dx", back: "F(g(x)) + C", group: "Metoder"),
        RuleCard(id: "i.parts", front: "Delvis integration\n∫ f·g′ dx", back: "f·g − ∫ f′·g dx", group: "Metoder"),
        RuleCard(id: "i.linear", front: "∫ f(kx + b) dx", back: "\\frac{1}{k}F(kx + b) + C", group: "Metoder"),
        RuleCard(id: "l.sinx", front: "lim_{x → 0} \\frac{sin(x)}{x}", back: "1", group: "Grænseværdier"),
        RuleCard(id: "l.e", front: "lim_{x → ∞} (1 + \\frac{1}{x})^{x}", back: "e", group: "Grænseværdier"),
        RuleCard(id: "l.ex", front: "lim_{x → 0} \\frac{e^{x} − 1}{x}", back: "1", group: "Grænseværdier"),
        RuleCard(id: "l.poly", front: "lim_{x → ∞} \\frac{a·x^{n} + …}{b·x^{n} + …}", back: "\\frac{a}{b}  (samme grad)", group: "Grænseværdier"),
        RuleCard(id: "i.definite", front: "∫_{a}^{b} f(x) dx", back: "F(b) − F(a)", group: "Metoder"),
        RuleCard(id: "p.partial", front: "∂f/∂x", back: "Differentiér efter x, y er en konstant", group: "Metoder"),
    ]
}
