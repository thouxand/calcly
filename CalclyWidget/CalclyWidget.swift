import WidgetKit
import SwiftUI

/// "Dagens regel": a new calculus rule on the home or lock screen every day.
struct RuleEntry: TimelineEntry {
    let date: Date
    let title: String
    let rule: String
    let answer: String
}

private let rules: [(String, String, String)] = [
    ("Potensreglen", "(xⁿ)′", "n·xⁿ⁻¹"),
    ("Standardafledt", "(eˣ)′", "eˣ"),
    ("Standardafledt", "(ln x)′", "1/x"),
    ("Standardafledt", "(sin x)′", "cos x"),
    ("Standardafledt", "(cos x)′", "−sin x"),
    ("Standardafledt", "(√x)′", "1/(2√x)"),
    ("Standardafledt", "(tan x)′", "1/cos²x"),
    ("Produktreglen", "(f·g)′", "f′g + fg′"),
    ("Kvotientreglen", "(f/g)′", "(f′g − fg′)/g²"),
    ("Kædereglen", "(f(g(x)))′", "f′(g(x))·g′(x)"),
    ("Kædereglen", "(e³ˣ)′", "3e³ˣ"),
    ("Integration", "∫ xⁿ dx", "xⁿ⁺¹/(n+1) + C"),
    ("Integration", "∫ 1/x dx", "ln|x| + C"),
    ("Integration", "∫ eˣ dx", "eˣ + C"),
    ("Integration", "∫ sin x dx", "−cos x + C"),
    ("Integration", "∫ cos x dx", "sin x + C"),
    ("Integration", "∫ eᵏˣ dx", "eᵏˣ/k + C"),
    ("Delvis integration", "∫ f·g′ dx", "fg − ∫ f′g dx"),
    ("Substitution", "∫ f(g(x))·g′(x) dx", "F(g(x)) + C"),
    ("Grænseværdi", "lim sin(x)/x, x→0", "1"),
    ("Grænseværdi", "lim (1 + 1/x)ˣ, x→∞", "e"),
    ("Bestemt integral", "∫ₐᵇ f(x) dx", "F(b) − F(a)"),
]

struct RuleProvider: TimelineProvider {
    func placeholder(in context: Context) -> RuleEntry { entry(for: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (RuleEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RuleEntry>) -> Void) {
        let now = Date()
        let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry(for: now)], policy: .after(tomorrow)))
    }

    /// The same rule all day, a new one tomorrow.
    private func entry(for date: Date) -> RuleEntry {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let r = rules[day % rules.count]
        return RuleEntry(date: date, title: r.0, rule: r.1, answer: r.2)
    }
}

struct CalclyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RuleEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Dagens regel").font(.caption2.weight(.bold))
                Text(entry.rule).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
                Text("= \(entry.answer)").font(.subheadline).lineLimit(1).minimumScaleFactor(0.6)
            }
        case .accessoryInline:
            Text("\(entry.rule) = \(entry.answer)")
        default:
            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
                HStack(spacing: 6) {
                    Text("∫").font(.system(size: 18, weight: .black, design: .serif))
                    Text("Dagens regel").font(.caption.weight(.heavy)).textCase(.uppercase)
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
                Text(entry.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(entry.rule)
                    .font(.system(family == .systemSmall ? .title3 : .title2, design: .rounded).weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("= \(entry.answer)")
                    .font(.system(family == .systemSmall ? .headline : .title3, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(.white)
        }
    }
}

struct CalclyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalclyRuleWidget", provider: RuleProvider()) { entry in
            CalclyWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.13, green: 0.77, blue: 0.37), Color(red: 0.05, green: 0.58, blue: 0.53)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Dagens regel")
        .description("En ny calculus-regel hver dag.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct CalclyWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalclyWidget()
    }
}
