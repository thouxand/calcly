import SwiftUI

/// "Lynrunde": as many right answers as possible in 60 seconds. Quick knowledge.
struct QuickView: View {
    @EnvironmentObject private var store: ProgressStore

    enum Scope: String, CaseIterable, Identifiable {
        case all = "Alt", diff = "Differentiation", integral = "Integration"
        var id: String { rawValue }
        var skills: [Skill] {
            let all = Skill.allCases.filter { ![.chainIdentify, .substitutionIdentify].contains($0) }
            switch self {
            case .all: return all
            case .diff: return all.filter { !$0.isIntegration && $0 != .limitsBasic && $0 != .limitsAlgebra }
            case .integral: return all.filter(\.isIntegration)
            }
        }
    }

    enum Phase { case ready, playing, done }

    static let duration: TimeInterval = 60

    @State private var scope: Scope = .all
    @State private var phase: Phase = .ready
    @State private var question: Exercise?
    @State private var picked: Int?
    @State private var score = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var endsAt = Date()
    @State private var now = Date()
    @State private var newBest = false
    @State private var tick = 0
    @State private var lastRight = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                switch phase {
                case .ready: ready
                case .playing: playing
                case .done: done
                }
            }
            .navigationTitle(phase == .playing ? "" : "Lynrunde")
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: phase)
        }
        .sensoryFeedback(trigger: tick) { _, _ in lastRight ? .success : .error }
    }

    // MARK: Screens

    private var ready: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack(alignment: .topTrailing) {
                Mascot(mood: .happy, size: 110)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Color.accentColor.gradient, in: Circle())
                    .offset(x: 10, y: -4)
            }
            VStack(spacing: 8) {
                Text("60 sekunder").font(.system(.largeTitle, design: .rounded).weight(.heavy))
                Text("Svar så hurtigt du kan. Rigtige svar i træk giver bonus.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Picker("Emne", selection: $scope) {
                ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Label("Rekord: \(store.state.bestQuick)", systemImage: "trophy.fill")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.gold)
            Spacer()
            Button("Start", action: startRound)
                .buttonStyle(ChunkyButtonStyle(color: .accentColor))
        }
        .padding(24)
    }

    private var playing: some View {
        VStack(spacing: 20) {
            HStack {
                timerRing.frame(width: 54, height: 54)
                Spacer()
                if combo >= 2 {
                    Text("\(combo)× i træk")
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.flame)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Label("\(score)", systemImage: "bolt.fill")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.gold)
                    .contentTransition(.numericText())
            }
            if let q = question {
                VStack(spacing: 18) {
                    Text(q.prompt)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.secondary)
                    MathText(markup: q.question, size: 28)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 12)
                        .glassCard(28)
                    answers(q)
                }
                .id(q.id)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            Spacer()
            Button("Stop") { finish() }
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .task(id: endsAt) {
            while !Task.isCancelled && phase == .playing {
                now = Date()
                if now >= endsAt { finish(); break }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: question?.id)
    }

    private var timerRing: some View {
        let left = max(0, endsAt.timeIntervalSince(now))
        return ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: left / Self.duration)
                .stroke(left < 10 ? Color.bad : Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(ceil(left)))")
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .monospacedDigit()
        }
        .animation(.linear(duration: 0.1), value: left)
    }

    @ViewBuilder private func answers(_ q: Exercise) -> some View {
        switch q.kind {
        case .choice(let options, let correct):
            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { i in
                    Button { answer(i, correct: i == correct) } label: { MathText(markup: options[i], size: 21, weight: .medium) }
                        .buttonStyle(OptionButtonStyle(state: state(i, correct: correct)))
                        .disabled(picked != nil)
                }
            }
        case .trueFalse(let truth):
            HStack(spacing: 14) {
                ForEach([1, 0], id: \.self) { i in
                    Button { answer(i, correct: (i == 1) == truth) } label: {
                        Label(i == 1 ? "Sandt" : "Falsk", systemImage: i == 1 ? "checkmark" : "xmark")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(OptionButtonStyle(state: state(i, correct: truth ? 1 : 0)))
                    .disabled(picked != nil)
                }
            }
        default:
            EmptyView()
        }
    }

    private var done: some View {
        VStack(spacing: 22) {
            Spacer()
            Text(newBest ? "Ny rekord!" : "Tiden er gået")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            Text("\(score)")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(Color.gold)
            Text("rigtige svar · bedste stime \(bestCombo)")
                .foregroundStyle(.secondary)
            Label("+\(score) XP", systemImage: "bolt.fill")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassCapsule(tint: Color.gold.opacity(0.2))
            Spacer()
            Button("Igen", action: startRound)
                .buttonStyle(ChunkyButtonStyle(color: .accentColor))
            Button("Færdig") { phase = .ready }
                .font(.headline)
        }
        .padding(24)
        .overlay { if newBest { ConfettiView(colors: [.gold, .flame, .good, .blue]).allowsHitTesting(false) } }
    }

    // MARK: Logic

    private func state(_ i: Int, correct: Int) -> OptionButtonStyle.OptionState {
        guard let picked else { return .normal }
        if i == correct { return .right }
        return i == picked ? .wrong : .faded
    }

    private func startRound() {
        score = 0
        combo = 0
        bestCombo = 0
        newBest = false
        picked = nil
        question = Generator.quick(scope.skills.randomElement()!)
        now = Date()
        endsAt = now.addingTimeInterval(Self.duration)
        phase = .playing
    }

    private func answer(_ i: Int, correct: Bool) {
        guard picked == nil, phase == .playing else { return }
        picked = i
        lastRight = correct
        tick += 1
        Sound.play(correct ? .correct : .wrong, enabled: store.state.sound)
        if correct {
            combo += 1
            bestCombo = max(bestCombo, combo)
            score += 1 + (combo >= 5 ? 1 : 0)       // bonus point for a streak of five
        } else {
            combo = 0
        }
        // Show the right answer a little longer after a mistake.
        DispatchQueue.main.asyncAfter(deadline: .now() + (correct ? 0.35 : 0.9)) {
            guard phase == .playing else { return }
            picked = nil
            question = Generator.quick(scope.skills.randomElement()!)
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        phase = .done
        newBest = score > store.state.bestQuick
        if newBest { store.state.bestQuick = score }
        store.state.addXP(score)
        _ = store.state.collectBadges()
        Sound.play(.complete, enabled: store.state.sound)
        Reminder.reschedule(store.state)
    }
}
