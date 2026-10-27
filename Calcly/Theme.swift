import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static let good = Color(hex: "#22C55E")
    static let bad = Color(hex: "#EF4444")
    static let flame = Color(hex: "#FB923C")
    static let heart = Color(hex: "#F43F5E")
    static let gold = Color(hex: "#EAB308")
}

// MARK: - Liquid Glass

/// Real Liquid Glass on iOS 26 (built with Xcode 26), frosted material before that.
struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color? = nil
    var interactive = false

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
    #endif

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint.opacity(0.55)) }
                    shape.fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .overlay { shape.stroke(Color.white.opacity(0.28), lineWidth: 1) }
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

extension View {
    func glassCard(_ radius: CGFloat = 26, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: radius, style: .continuous), tint: tint, interactive: interactive))
    }

    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: Capsule(), tint: tint, interactive: interactive))
    }

    func glassCircle(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: Circle(), tint: tint, interactive: interactive))
    }
}

// MARK: - Buttons

/// The chunky, pressable Duolingo button: a coloured top that sinks into its darker base.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var foreground: Color = .white
    var depth: CGFloat = 5
    var radius: CGFloat = 18
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        let fill = enabled ? color : Color.gray.opacity(0.45)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return configuration.label
            .font(.system(.headline, design: .rounded).weight(.heavy))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(enabled ? foreground : .white.opacity(0.8))
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                shape.fill(fill)
                    .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)))
            }
            .background { shape.fill(fill).overlay(shape.fill(.black.opacity(0.25))).offset(y: pressed ? 0 : depth) }
            .offset(y: pressed ? depth : 0)
            .padding(.bottom, depth)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }
}

/// An answer option: glass with a bottom edge, outlined in colour when chosen.
struct OptionButtonStyle: ButtonStyle {
    var state: OptionState = .normal

    enum OptionState { case normal, selected, right, wrong, faded }

    private var color: Color {
        switch state {
        case .normal, .faded: return .secondary
        case .selected: return .accentColor
        case .right: return .good
        case .wrong: return .bad
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let pressed = configuration.isPressed
        let highlighted = state != .normal && state != .faded
        return configuration.label
            .frame(maxWidth: .infinity, minHeight: 58)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                shape.fill(highlighted ? color.opacity(0.16) : Color.clear)
            }
            .glassCard(18)
            .overlay { shape.strokeBorder(color.opacity(highlighted ? 0.95 : 0.25), lineWidth: highlighted ? 2.5 : 1) }
            .background { shape.fill(color.opacity(highlighted ? 0.55 : 0.18)).offset(y: pressed ? 0 : 4) }
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 4)
            .opacity(state == .faded ? 0.45 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
            .animation(.smooth(duration: 0.2), value: state)
    }
}

/// Springy press feedback for plain custom buttons.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Background

/// Softly moving colour behind everything, so the glass has something to bend.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme
    var accent: Color = .accentColor

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let t = context.date.timeIntervalSinceReferenceDate / 6
            let w = Float(sin(t) * 0.08), v = Float(cos(t * 0.8) * 0.08)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + w, 0], [1, 0],
                    [0, 0.5 + v], [0.5 - w, 0.5 + v], [1, 0.5 - v],
                    [0, 1], [0.5 + v, 1], [1, 1],
                ],
                colors: scheme == .dark ? darkColors : lightColors
            )
        }
        .ignoresSafeArea()
    }

    private var lightColors: [Color] {
        [Color(hex: "#E0F2FE"), .white, Color(hex: "#DBEAFE"),
         .white, Color(hex: "#F0F9FF"), Color(hex: "#E0F2FE"),
         Color(hex: "#BAE6FD"), .white, Color(hex: "#E0F2FE")]
    }

    private var darkColors: [Color] {
        [Color(hex: "#0B1220"), Color(hex: "#0C2340"), Color(hex: "#081426"),
         Color(hex: "#0A1628"), Color(hex: "#05080F"), Color(hex: "#0B2545"),
         Color(hex: "#0C1E36"), Color(hex: "#070D18"), Color(hex: "#0E3A5C")]
    }
}

// MARK: - Layout

/// Lays children out left to right and wraps onto new lines (word bank tiles).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { x = 0; y += lineHeight + lineSpacing; lineHeight = 0 }
            x += s.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, s.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Lines are centred.
        var lines: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > bounds.width { lines.append([]); x = 0 }
            lines[lines.count - 1].append((v, s))
            x += s.width + spacing
        }
        var y = bounds.minY
        for line in lines {
            let width = line.map(\.1.width).reduce(0, +) + spacing * CGFloat(max(0, line.count - 1))
            let height = line.map(\.1.height).max() ?? 0
            var x = bounds.minX + (bounds.width - width) / 2
            for (v, s) in line {
                v.place(at: CGPoint(x: x, y: y + (height - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += height + lineSpacing
        }
    }
}
