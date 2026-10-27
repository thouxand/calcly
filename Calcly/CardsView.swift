import SwiftUI

/// "Regelkort": the rules as flash cards, repeated less often the better you know them.
struct CardsView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var session: [RuleCard] = []
    @State private var inSession = false
    @State private var flipped = false
    @State private var known = 0
    @State private var seen = 0
    @State private var drag: CGSize = .zero
    @State private var retried: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if inSession { sessionView } else { overview }
            }
            .navigationTitle(inSession ? "" : "Regelkort")
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: inSession)
        }
    }

    // MARK: Overview

    private var overview: some View {
        let due = store.state.dueCards()
        let mastered = store.state.masteredCards
        return ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(due.count) kort klar")
                                .font(.system(.title2, design: .rounded).weight(.heavy))
                            Text("\(mastered) af \(Course.cards.count) sidder på rygraden")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        GoalRing(progress: Double(mastered) / Double(Course.cards.count)).frame(width: 52, height: 52)
                    }
                    if due.isEmpty {
                        Text("Alt er på plads for i dag. Kortene kommer igen, lige før du glemmer dem.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Øv alle kort alligevel") { begin(Array(Course.cards.shuffled().prefix(15))) }
                            .buttonStyle(ChunkyButtonStyle(color: .accentColor))
                    } else {
                        Button("Start") { begin(due) }
                            .buttonStyle(ChunkyButtonStyle(color: .accentColor))
                    }
                }
                .padding(20)
                .glassCard()

                ForEach(groups, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group)
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .padding(.leading, 6)
                        VStack(spacing: 0) {
                            ForEach(Course.cards.filter { $0.group == group }) { card in
                                HStack(spacing: 12) {
                                    MathText(markup: card.front.replacingOccurrences(of: "\n", with: " "), size: 17, weight: .medium)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    BoxDots(box: store.state.card(card.id).box)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                if card.id != Course.cards.last(where: { $0.group == group })?.id {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .glassCard(22)
                    }
                }
            }
            .padding(20)
        }
    }

    private var groups: [String] {
        var out: [String] = []
        for c in Course.cards where !out.contains(c.group) { out.append(c.group) }
        return out
    }

    // MARK: Session

    @ViewBuilder private var sessionView: some View {
        if let card = session.first {
            VStack(spacing: 22) {
                HStack {
                    Button { inSession = false } label: {
                        Image(systemName: "xmark").font(.headline.weight(.bold)).frame(width: 40, height: 40).glassCircle(interactive: true)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Luk")
                    Spacer()
                    Text("\(session.count) tilbage")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                FlashCard(card: card, flipped: flipped)
                    .offset(x: drag.width, y: drag.height * 0.2)
                    .rotationEffect(.degrees(Double(drag.width) / 18))
                    .overlay(alignment: .top) { swipeHint }
                    .onTapGesture { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { flipped.toggle() } }
                    .gesture(
                        DragGesture()
                            .onChanged { if flipped { drag = $0.translation } }
                            .onEnded { value in
                                guard flipped else { return }
                                if value.translation.width > 110 { grade(true) }
                                else if value.translation.width < -110 { grade(false) }
                                else { withAnimation(.spring) { drag = .zero } }
                            }
                    )
                    .id(card.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
                Spacer()
                if flipped {
                    HStack(spacing: 14) {
                        Button("Kunne ikke") { grade(false) }
                            .buttonStyle(ChunkyButtonStyle(color: .bad))
                        Button("Kunne") { grade(true) }
                            .buttonStyle(ChunkyButtonStyle(color: .good))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Button("Vend kortet") { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { flipped = true } }
                        .buttonStyle(ChunkyButtonStyle(color: .accentColor))
                }
            }
            .padding(20)
            .sensoryFeedback(.impact(weight: .light), trigger: flipped)
        } else {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.good)
                Text("Godt gået!").font(.system(.largeTitle, design: .rounded).weight(.heavy))
                Text("Du kunne \(known) af \(seen) kort.")
                    .foregroundStyle(.secondary)
                Label("+\(known) XP", systemImage: "bolt.fill")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassCapsule(tint: Color.gold.opacity(0.2))
                Spacer()
                Button("Færdig") { inSession = false }
                    .buttonStyle(ChunkyButtonStyle(color: .good))
            }
            .padding(24)
            .overlay { ConfettiView(colors: [.good, .gold, .blue, .flame]).allowsHitTesting(false) }
        }
    }

    @ViewBuilder private var swipeHint: some View {
        if abs(drag.width) > 30 {
            Text(drag.width > 0 ? "Kunne" : "Kunne ikke")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(drag.width > 0 ? Color.good : Color.bad, in: Capsule())
                .offset(y: -18)
        }
    }

    private func begin(_ cards: [RuleCard]) {
        session = cards
        known = 0
        seen = 0
        retried = []
        flipped = false
        drag = .zero
        inSession = true
    }

    private func grade(_ knew: Bool) {
        guard let card = session.first else { return }
        store.state.grade(card.id, knew: knew)
        seen += 1
        if knew {
            known += 1
            store.state.addXP(1)
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            session.removeFirst()
            // One more go at the end for a card you didn't know.
            if !knew && !retried.contains(card.id) {
                retried.insert(card.id)
                session.append(card)
            }
            flipped = false
            drag = .zero
        }
    }
}

private struct FlashCard: View {
    let card: RuleCard
    let flipped: Bool

    var body: some View {
        ZStack {
            face(card.front, label: card.group, tint: .accentColor)
                .opacity(flipped ? 0 : 1)
            face(card.back, label: "Svar", tint: .good)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }

    private func face(_ markup: String, label: String, tint: Color) -> some View {
        VStack(spacing: 18) {
            Text(label)
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(tint)
            MathText(markup: markup, size: 30)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(20)
        .glassCard(34, tint: tint.opacity(0.08))
        .contentShape(Rectangle())
    }
}

/// How well a card sits: five dots.
private struct BoxDots: View {
    let box: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= box ? Color.good : Color.primary.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityLabel("Niveau \(box) af 5")
    }
}
