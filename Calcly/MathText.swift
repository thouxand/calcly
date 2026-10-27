import SwiftUI

/// Shows maths markup. Each line of the string is a line on screen. Fractions are stacked;
/// a line that is too wide shrinks to fit.
struct MathText: View {
    let markup: String
    var size: CGFloat = 22
    var weight: Font.Weight = .semibold
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: size * 0.35) {
            ForEach(Array(markup.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                MathLine(tokens: MathToken.parse(line), size: size, weight: weight)
            }
        }
    }
}

private struct MathLine: View {
    let tokens: [MathToken]
    let size: CGFloat
    let weight: Font.Weight

    var body: some View {
        if tokens.contains(where: \.hasFraction) {
            ViewThatFits(in: .horizontal) {
                ForEach([1.0, 0.85, 0.72, 0.6, 0.5], id: \.self) { scale in
                    row(size * scale)
                }
            }
        } else {
            Text(Self.attributed(tokens, size: size, weight: weight, baseline: 0))
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        }
    }

    private func row(_ s: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 1) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                switch seg {
                case .run(let run):
                    Text(Self.attributed(run, size: s, weight: weight, baseline: 0))
                        .fixedSize()
                case .frac(let a, let b):
                    VStack(spacing: s * 0.08) {
                        // AnyView breaks the recursive view type (a fraction inside a fraction).
                        AnyView(MathLine(tokens: a, size: s * 0.82, weight: weight).fixedSize())
                        Capsule().frame(height: max(1.2, s * 0.07))
                        AnyView(MathLine(tokens: b, size: s * 0.82, weight: weight).fixedSize())
                    }
                    .fixedSize()
                    .padding(.horizontal, s * 0.12)
                }
            }
        }
        .fixedSize()
    }

    private enum Segment { case run([MathToken]), frac([MathToken], [MathToken]) }

    private var segments: [Segment] {
        var out: [Segment] = []
        var run: [MathToken] = []
        for t in tokens {
            if case .frac(let a, let b) = t {
                if !run.isEmpty { out.append(.run(run)); run = [] }
                out.append(.frac(a, b))
            } else {
                run.append(t)
            }
        }
        if !run.isEmpty { out.append(.run(run)) }
        return out
    }

    /// Text and superscripts as one attributed string; fractions inside exponents become a/b.
    static func attributed(_ tokens: [MathToken], size: CGFloat, weight: Font.Weight, baseline: CGFloat) -> AttributedString {
        var out = AttributedString()
        for t in tokens {
            switch t {
            case .text(let s):
                var a = AttributedString(s)
                a.font = .system(size: size, weight: weight, design: .rounded)
                a.baselineOffset = baseline
                out += a
            case .sup(let inner):
                out += attributed(inner, size: size * 0.64, weight: weight, baseline: baseline + size * 0.42)
            case .sub(let inner):
                out += attributed(inner, size: size * 0.6, weight: weight, baseline: baseline - size * 0.22)
            case .frac(let a, let b):
                func plain(_ text: String) -> AttributedString {
                    var p = AttributedString(text)
                    p.font = .system(size: size, weight: weight, design: .rounded)
                    p.baselineOffset = baseline
                    return p
                }
                out += plain("(") + attributed(a, size: size, weight: weight, baseline: baseline) + plain(")/(")
                    + attributed(b, size: size, weight: weight, baseline: baseline) + plain(")")
            }
        }
        return out
    }
}
