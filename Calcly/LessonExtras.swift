import SwiftUI
import Charts

// MARK: - Typed answers

/// Answer field plus a maths keyboard.
struct TypedAnswerView: View {
    @Binding var keys: [String]
    let locked: Bool
    let upToConstant: Bool
    let color: Color

    private let rows: [[String]] = [
        ["7", "8", "9", "x", "(", ")"],
        ["4", "5", "6", "^", "sin(", "cos("],
        ["1", "2", "3", "·", "/", "e^"],
        ["0", ",", "+", "−", "ln(", "√("],
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                if keys.isEmpty {
                    Text("Skriv dit svar")
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundStyle(.tertiary)
                } else {
                    MathText(markup: Evaluator.display(keys: keys), size: 26)
                }
                Rectangle().fill(color).frame(width: 2.5, height: 28).opacity(locked ? 0 : 1)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .glassCard(20)
            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(color.opacity(0.6), lineWidth: 2) }
            if upToConstant {
                Text("Du behøver ikke skrive + C").font(.footnote).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button { tap(key) } label: {
                                Text(label(key))
                                    .font(.system(size: key.count > 2 ? 16 : 21, weight: .semibold, design: .rounded))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(KeyStyle())
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button { if !locked { keys.removeAll() } } label: {
                        Text("Ryd").font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(KeyStyle())
                    Button { if !locked, !keys.isEmpty { keys.removeLast() } } label: {
                        Image(systemName: "delete.left.fill").font(.title3).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(KeyStyle())
                    .accessibilityLabel("Slet")
                }
            }
            .disabled(locked)
            .sensoryFeedback(.selection, trigger: keys)
        }
    }

    private func label(_ key: String) -> String {
        switch key {
        case "^": return "xⁿ"
        case "e^": return "eˣ"
        case "sin(", "cos(", "ln(": return String(key.dropLast())
        case "√(": return "√"
        default: return key
        }
    }

    private func tap(_ key: String) {
        guard !locked else { return }
        keys.append(key)
    }
}

private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassCard(12, interactive: true)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.12)).offset(y: configuration.isPressed ? 0 : 3))
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Step by step

struct StepsView: View {
    let steps: [Exercise.Step]
    @Binding var draft: AnswerDraft
    let locked: Bool
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Steps already solved.
            ForEach(Array(steps.prefix(draft.step).enumerated()), id: \.offset) { i, step in
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.good).font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.prompt).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        MathText(markup: step.options[step.correct], size: 19, alignment: .leading)
                    }
                    Spacer()
                }
                .padding(12)
                .glassCard(16, tint: Color.good.opacity(0.1))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if draft.step < steps.count {
                let step = steps[draft.step]
                HStack {
                    Text(step.prompt).font(.system(.headline, design: .rounded).weight(.heavy))
                    Spacer()
                    Text("\(draft.step + 1)/\(steps.count)").font(.subheadline.weight(.bold)).foregroundStyle(color)
                }
                VStack(spacing: 12) {
                    ForEach(step.options.indices, id: \.self) { i in
                        Button { if !locked { draft.choice = i } } label: {
                            MathText(markup: step.options[i], size: 21, weight: .medium)
                        }
                        .buttonStyle(OptionButtonStyle(state: state(i, correct: step.correct)))
                    }
                }
                .id(draft.step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: draft.step)
        .sensoryFeedback(.selection, trigger: draft.choice)
    }

    private func state(_ i: Int, correct: Int) -> OptionButtonStyle.OptionState {
        if locked {
            if i == correct { return .right }
            if i == draft.choice { return .wrong }
            return .faded
        }
        return draft.choice == i ? .selected : .normal
    }
}

// MARK: - Graphs

/// f and f′ drawn together, to see what the derivative means.
struct GraphView: View {
    let f: String
    let d: String

    private struct Point: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let name: String
        let segment: String
    }

    private var points: [Point] {
        guard let ef = Expression(Evaluator.plain(f)), let ed = Expression(Evaluator.plain(d)) else { return [] }
        // Functions like ln and √ only exist for x > 0.
        let wide = stride(from: -3.0, through: 3.0, by: 0.05).filter { ef.value(at: $0).isFinite }
        let xs = wide.count > 90 ? Array(stride(from: -3.0, through: 3.0, by: 0.05)) : Array(stride(from: 0.05, through: 4.0, by: 0.04))
        var out: [Point] = []
        for (name, e) in [("f", ef), ("f′", ed)] {
            var segment = 0
            var last: Double?
            for x in xs {
                let y = e.value(at: x)
                guard y.isFinite, abs(y) <= 10 else { segment += 1; last = nil; continue }
                if let l = last, abs(y - l) > 6 { segment += 1 }
                out.append(Point(x: x, y: y, name: name, segment: "\(name)\(segment)"))
                last = y
            }
        }
        return out
    }

    var body: some View {
        Chart(points) { p in
            LineMark(x: .value("x", p.x), y: .value("y", p.y), series: .value("del", p.segment))
                .foregroundStyle(by: .value("Funktion", p.name))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale(["f": Color.accentColor, "f′": Color.flame])
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 180)
        .accessibilityLabel("Graf af f og f′")
    }
}
