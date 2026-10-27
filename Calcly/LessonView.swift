import SwiftUI

/// What the player has answered so far in the current exercise.
struct AnswerDraft: Equatable {
    var choice: Int?
    var truth: Bool?
    var tiles: [Int] = []
    var typed: [String] = []
    /// Current step in a step-by-step exercise.
    var step = 0

    func isReady(for kind: Exercise.Kind) -> Bool {
        switch kind {
        case .choice, .steps: return choice != nil
        case .trueFalse: return truth != nil
        case .build: return !tiles.isEmpty
        case .typed: return !typed.isEmpty
        case .match: return false
        }
    }

    func isCorrect(for kind: Exercise.Kind) -> Bool {
        switch kind {
        case .choice(_, let correct): return choice == correct
        case .trueFalse(let t): return truth == t
        case .build(let tiles, let answers): return answers.contains(self.tiles.map { tiles[$0] })
        case .typed(let answer, let upToConstant):
            return Evaluator.equivalent(Evaluator.plain(keys: typed), answer, upToConstant: upToConstant)
        case .steps(let steps): return step < steps.count && choice == steps[step].correct
        case .match: return true
        }
    }
}

extension Exercise {
    /// The right answer as markup, for the feedback panel.
    func rightAnswer(_ draft: AnswerDraft) -> String {
        switch kind {
        case .choice(let o, let c): return o[c]
        case .trueFalse(let t): return t ? "Sandt" : "Falsk"
        case .build(_, let answers): return answers[0].joined(separator: " ")
        case .typed(let answer, _): return answer
        case .steps(let steps):
            let s = steps[min(draft.step, steps.count - 1)]
            return s.options[s.correct]
        case .match: return ""
        }
    }
}

struct LessonView: View {
    @EnvironmentObject private var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    let lesson: Lesson
    /// Set for "Øv dine fejl": these exercises instead of new ones.
    var review: [Exercise]? = nil

    @State private var queue: [Exercise] = []
    @State private var total = Course.exercisesPerLesson
    @State private var solved = 0
    @State private var mistakes = 0
    @State private var draft = AnswerDraft()
    @State private var result: Bool?
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var startedAt = Date()
    @State private var finished: LessonResult?
    @State private var confirmQuit = false
    @State private var outOfHearts = false
    @State private var feedbackTick = 0

    private var color: Color { Color(hex: Course.unit(of: lesson)?.colorHex ?? "#0EA5E9") }
    private var current: Exercise? { queue.first }

    var body: some View {
        ZStack {
            AppBackground()
            if let finished {
                LessonResultView(result: finished, color: color) { dismiss() }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let e = current {
                VStack(spacing: 0) {
                    topBar.padding(.horizontal, 18).padding(.top, 8)
                    ScrollView {
                        ExerciseView(exercise: e, draft: $draft, locked: result != nil, color: color, review: review != nil) {
                            // Matching finishes by itself.
                            check(force: true)
                        }
                        .id(e.id)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 200)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .overlay(alignment: .bottom) { bottomPanel(e) }
            }
        }
        .onAppear(perform: start)
        .sensoryFeedback(trigger: feedbackTick) { _, _ in result == true ? .success : .error }
        .confirmationDialog("Vil du stoppe?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Stop lektionen", role: .destructive) { dismiss() }
            Button("Fortsæt", role: .cancel) {}
        } message: {
            Text("Du mister det, du har lavet i denne lektion.")
        }
        .overlay { if outOfHearts { heartsOverlay } }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: queue.first?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: result)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: finished != nil)
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                if solved > 0 || mistakes > 0 { confirmQuit = true } else { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .glassCircle(interactive: true)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Luk")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(color.gradient)
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.35)).frame(height: 4).padding(.horizontal, 8).padding(.top, 3)
                        }
                        .frame(width: max(16, geo.size.width * Double(solved) / Double(max(1, total))))
                }
            }
            .frame(height: 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: solved)

            if combo >= 3 {
                Text("\(combo)×")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.flame)
                    .transition(.scale.combined(with: .opacity))
            }
            if store.state.useHearts {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").foregroundStyle(Color.heart)
                    Text("\(store.state.hearts)").contentTransition(.numericText())
                }
                .font(.system(.headline, design: .rounded).weight(.heavy))
            }
        }
    }

    @ViewBuilder private func bottomPanel(_ e: Exercise) -> some View {
        if let result {
            FeedbackPanel(correct: result, exercise: e, answer: e.rightAnswer(draft), color: color) { next() }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if case .match = e.kind {
            EmptyView()
        } else {
            Button("Tjek") { check() }
                .buttonStyle(ChunkyButtonStyle(color: color))
                .disabled(!draft.isReady(for: e.kind))
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .background(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color(uiColor: .systemBackground).opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
        }
    }

    private var heartsOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.heart)
                Text("Ingen hjerter tilbage")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                if let next = store.state.nextHeart() {
                    Text("Næste hjerte om \(Int(ceil(next / 60))) min.")
                        .foregroundStyle(.secondary)
                }
                Button("Slå hjerter fra og fortsæt") {
                    store.state.useHearts = false
                    outOfHearts = false
                }
                .buttonStyle(ChunkyButtonStyle(color: .heart))
                Button("Afslut") { dismiss() }
                    .font(.headline)
            }
            .padding(26)
            .glassCard(32)
            .padding(28)
        }
        .transition(.opacity)
    }

    // MARK: Flow

    private func start() {
        guard queue.isEmpty else { return }
        queue = review ?? Course.exercises(for: lesson)
        total = queue.count
        startedAt = Date()
        store.refresh()
        if store.state.useHearts && store.state.hearts == 0 { outOfHearts = true }
    }

    private func check(force: Bool = false) {
        guard let e = current, result == nil else { return }
        let ok = force || draft.isCorrect(for: e.kind)
        // A right step that isn't the last one just moves on to the next step.
        if ok, case .steps(let steps) = e.kind, draft.step < steps.count - 1 {
            Sound.play(.flip, enabled: store.state.sound)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                draft.step += 1
                draft.choice = nil
            }
            return
        }
        result = ok
        feedbackTick += 1
        Sound.play(ok ? .correct : .wrong, enabled: store.state.sound)
        if case .match = e.kind {} else { store.state.recordAnswer(correct: ok) }
        if ok {
            combo += 1
            bestCombo = max(bestCombo, combo)
            if review != nil { store.state.clearMistake(e) }
        } else {
            combo = 0
            mistakes += 1
            store.state.addMistake(e)
            if store.state.useHearts { store.state.loseHeart() }
        }
    }

    private func next() {
        guard let e = queue.first, let ok = result else { return }
        queue.removeFirst()
        if ok {
            solved += 1
        } else {
            queue.append(e)          // mistakes come back at the end
        }
        draft = AnswerDraft()
        result = nil
        if store.state.useHearts && store.state.hearts == 0 && !queue.isEmpty {
            outOfHearts = true
            return
        }
        if queue.isEmpty { finish() }
    }

    private func finish() {
        let perfect = mistakes == 0
        let xp = 10 + (perfect ? 5 : 0) + min(5, bestCombo / 3)
        let before = store.state.currentStreak()
        let extended = store.state.addXP(xp)
        if review == nil {
            store.state.completeLesson(lesson)
            if perfect { store.state.perfectLessons += 1 }
        }
        let badges = store.state.collectBadges()
        Sound.play(.complete, enabled: store.state.sound)
        Reminder.reschedule(store.state)
        finished = LessonResult(xp: xp, accuracy: Double(total) / Double(total + mistakes), seconds: Date().timeIntervalSince(startedAt),
                                perfect: perfect, streak: store.state.currentStreak(), streakGrew: extended && store.state.currentStreak() > before,
                                crowns: review == nil ? store.state.crowns(lesson) : nil, badges: badges.map(\.id))
    }
}

struct LessonResult: Equatable {
    let xp: Int
    let accuracy: Double
    let seconds: TimeInterval
    let perfect: Bool
    let streak: Int
    let streakGrew: Bool
    /// nil for a review session.
    let crowns: Int?
    let badges: [String]
}

// MARK: - Exercise views

struct ExerciseView: View {
    let exercise: Exercise
    @Binding var draft: AnswerDraft
    let locked: Bool
    let color: Color
    var review = false
    let onMatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if review {
                Label("Fra dine fejl", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.heart)
            }
            Text(exercise.prompt)
                .font(.system(.title2, design: .rounded).weight(.heavy))
            if !exercise.question.isEmpty {
                MathText(markup: exercise.question, size: 30, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 14)
                    .glassCard(28)
            }
            switch exercise.kind {
            case .choice(let options, _):
                VStack(spacing: 12) {
                    ForEach(options.indices, id: \.self) { i in
                        Button { if !locked { draft.choice = i } } label: {
                            MathText(markup: options[i], size: 22, weight: .medium)
                        }
                        .buttonStyle(OptionButtonStyle(state: optionState(i)))
                        .sensoryFeedback(.selection, trigger: draft.choice)
                    }
                }
            case .trueFalse:
                HStack(spacing: 14) {
                    ForEach([true, false], id: \.self) { value in
                        Button { if !locked { draft.truth = value } } label: {
                            Label(value ? "Sandt" : "Falsk", systemImage: value ? "checkmark" : "xmark")
                                .font(.system(.title3, design: .rounded).weight(.heavy))
                                .padding(.vertical, 18)
                        }
                        .buttonStyle(OptionButtonStyle(state: truthState(value)))
                    }
                }
            case .build(let tiles, _):
                BuildAnswerView(tiles: tiles, picked: $draft.tiles, locked: locked)
            case .match(let left, let right):
                MatchView(left: left, right: right, color: color, onDone: onMatched)
            case .steps(let steps):
                StepsView(steps: steps, draft: $draft, locked: locked, color: color)
            case .typed(_, let upToConstant):
                TypedAnswerView(keys: $draft.typed, locked: locked, upToConstant: upToConstant, color: color)
            }
        }
    }

    private func optionState(_ i: Int) -> OptionButtonStyle.OptionState {
        guard case .choice(_, let correct) = exercise.kind else { return .normal }
        if locked {
            if i == correct { return .right }
            if i == draft.choice { return .wrong }
            return .faded
        }
        return draft.choice == i ? .selected : .normal
    }

    private func truthState(_ value: Bool) -> OptionButtonStyle.OptionState {
        guard case .trueFalse(let truth) = exercise.kind else { return .normal }
        if locked {
            if value == truth { return .right }
            if value == draft.truth { return .wrong }
            return .faded
        }
        return draft.truth == value ? .selected : .normal
    }
}

/// Tap tiles to build the answer; tap a placed tile to take it back.
private struct BuildAnswerView: View {
    let tiles: [String]
    @Binding var picked: [Int]
    let locked: Bool
    @Namespace private var space

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 0) {
                FlowLayout(spacing: 8, lineSpacing: 10) {
                    ForEach(picked, id: \.self) { i in
                        tile(i).matchedGeometryEffect(id: i, in: space)
                            .onTapGesture { if !locked { withAnimation(.spring(response: 0.3)) { picked.removeAll { $0 == i } } } }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.vertical, 8)
                Rectangle().fill(Color.primary.opacity(0.15)).frame(height: 2)
            }
            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(tiles.indices, id: \.self) { i in
                    ZStack {
                        tile(i).opacity(0)       // keeps the slot's size
                        if !picked.contains(i) {
                            tile(i).matchedGeometryEffect(id: i, in: space)
                                .onTapGesture { if !locked { withAnimation(.spring(response: 0.3)) { picked.append(i) } } }
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.08))
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: picked)
    }

    private func tile(_ i: Int) -> some View {
        MathText(markup: tiles[i], size: 20, weight: .semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .fixedSize()
            .glassCard(14, interactive: true)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.12)).offset(y: 3))
            .contentShape(Rectangle())
    }
}

/// Tap a function, then its partner. Right pairs light up and fade.
private struct MatchView: View {
    let left: [String]
    let right: [String]
    let color: Color
    let onDone: () -> Void

    @State private var rightOrder: [Int] = []
    @State private var pickedLeft: Int?
    @State private var pickedRight: Int?
    @State private var matched: Set<Int> = []
    @State private var wrongPair: (Int, Int)?
    @State private var tick = 0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                ForEach(left.indices, id: \.self) { i in
                    Button { tapLeft(i) } label: { MathText(markup: left[i], size: 19, weight: .medium) }
                        .buttonStyle(OptionButtonStyle(state: state(left: i)))
                        .disabled(matched.contains(i))
                }
            }
            VStack(spacing: 12) {
                ForEach(rightOrder, id: \.self) { j in
                    Button { tapRight(j) } label: { MathText(markup: right[j], size: 19, weight: .medium) }
                        .buttonStyle(OptionButtonStyle(state: state(right: j)))
                        .disabled(matched.contains(j))
                }
            }
        }
        .onAppear { if rightOrder.isEmpty { rightOrder = Array(right.indices).shuffled() } }
        .sensoryFeedback(.selection, trigger: tick)
    }

    private func state(left i: Int) -> OptionButtonStyle.OptionState {
        if matched.contains(i) { return .faded }
        if wrongPair?.0 == i { return .wrong }
        return pickedLeft == i ? .selected : .normal
    }

    private func state(right j: Int) -> OptionButtonStyle.OptionState {
        if matched.contains(j) { return .faded }
        if wrongPair?.1 == j { return .wrong }
        return pickedRight == j ? .selected : .normal
    }

    private func tapLeft(_ i: Int) { pickedLeft = i; tick += 1; resolve() }
    private func tapRight(_ j: Int) { pickedRight = j; tick += 1; resolve() }

    private func resolve() {
        guard let i = pickedLeft, let j = pickedRight else { return }
        pickedLeft = nil
        pickedRight = nil
        if i == j {
            withAnimation(.smooth) { _ = matched.insert(i) }
            if matched.count == left.count { onDone() }
        } else {
            wrongPair = (i, j)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { withAnimation { wrongPair = nil } }
        }
    }
}

// MARK: - Feedback

private struct FeedbackPanel: View {
    let correct: Bool
    let exercise: Exercise
    let answer: String
    let color: Color
    let onContinue: () -> Void
    @State private var showWhy = false
    @State private var showGraph = false

    private static let praise = ["Fantastisk!", "Flot!", "Præcis!", "Godt gået!", "Sådan!", "Helt rigtigt!"]
    @State private var title = FeedbackPanel.praise.randomElement()!

    var body: some View {
        let tone: Color = correct ? .good : .bad
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Mascot(mood: correct ? .cheer : .sad, size: 34)
                    .frame(width: 42, height: 44)
                Text(correct ? title : "Ikke helt")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                Spacer()
                if let f = exercise.graphF, let d = exercise.graphD, !f.isEmpty, !d.isEmpty {
                    Button { withAnimation(.smooth) { showGraph.toggle() } } label: {
                        Image(systemName: showGraph ? "chart.xyaxis.line" : "chart.line.uptrend.xyaxis").font(.title2)
                    }
                    .accessibilityLabel("Vis graf")
                }
                if !exercise.explanation.isEmpty {
                    Button { withAnimation(.smooth) { showWhy.toggle() } } label: {
                        Image(systemName: showWhy ? "chevron.down.circle.fill" : "questionmark.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Forklaring")
                }
            }
            .foregroundStyle(tone)
            if !correct, !answer.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rigtigt svar:").font(.subheadline.weight(.bold)).foregroundStyle(tone)
                    MathText(markup: answer, size: 22, weight: .semibold, alignment: .leading)
                }
            }
            if showGraph, let f = exercise.graphF, let d = exercise.graphD {
                GraphView(f: f, d: d)
                    .transition(.opacity)
            }
            if showWhy || !correct {
                MathText(markup: exercise.explanation, size: 16, weight: .medium, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            Button(correct ? "Fortsæt" : "Forstået", action: onContinue)
                .buttonStyle(ChunkyButtonStyle(color: tone))
        }
        .padding(20)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(tone.opacity(0.14), in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
        .glassCard(30, tint: tone.opacity(0.12))
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Result

struct LessonResultView: View {
    let result: LessonResult
    let color: Color
    let onDone: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Mascot(mood: .cheer, size: 120)
                .scaleEffect(appear ? 1 : 0.3)
                .rotationEffect(.degrees(appear ? 0 : -20))
            Text(result.perfect ? "Fejlfrit!" : "Lektion klaret!")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
            if let crowns = result.crowns {
                HStack(spacing: 4) {
                    ForEach(0..<ProgressState.maxCrowns, id: \.self) { i in
                        Image(systemName: "crown.fill").foregroundStyle(i < crowns ? Color.gold : Color.secondary.opacity(0.3))
                    }
                }
                .font(.title3)
            }
            HStack(spacing: 12) {
                tile("XP", "+\(result.xp)", "bolt.fill", .gold)
                tile("Præcision", "\(Int((result.accuracy * 100).rounded())) %", "target", .good)
                tile("Tid", time(result.seconds), "stopwatch.fill", .blue)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)
            ForEach(Badge.all.filter { result.badges.contains($0.id) }) { badge in
                HStack(spacing: 12) {
                    Image(systemName: badge.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color(hex: badge.colorHex).gradient, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ny bedrift: \(badge.title)").font(.system(.headline, design: .rounded).weight(.heavy))
                        Text(badge.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .glassCard(20, tint: Color(hex: badge.colorHex).opacity(0.12))
                .padding(.horizontal, 20)
                .opacity(appear ? 1 : 0)
            }
            if result.streakGrew {
                Label("\(result.streak) \(result.streak == 1 ? "dag" : "dage") i træk!", systemImage: "flame.fill")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.flame)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .glassCapsule(tint: Color.flame.opacity(0.2))
            }
            Spacer()
            Button("Fortsæt", action: onDone)
                .buttonStyle(ChunkyButtonStyle(color: color))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
        .overlay { ConfettiView(colors: [color, .gold, .good, .flame, .heart, .blue]).allowsHitTesting(false) }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) { appear = true } }
        .sensoryFeedback(.success, trigger: appear)
    }

    private func tile(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(tint)
            Label(value, systemImage: symbol)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(20, tint: tint.opacity(0.12))
    }

    private func time(_ s: TimeInterval) -> String {
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

/// A short burst of confetti.
struct ConfettiView: View {
    let colors: [Color]
    @State private var start = Date()
    @State private var pieces: [Piece] = (0..<90).map { _ in Piece() }

    struct Piece {
        let x = Double.random(in: 0...1)
        let speed = Double.random(in: 0.35...0.8)
        let drift = Double.random(in: -0.15...0.15)
        let spin = Double.random(in: -6...6)
        let delay = Double.random(in: 0...0.5)
        let size = Double.random(in: 6...12)
        let color = Int.random(in: 0..<100)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                guard t < 4 else { return }
                for p in pieces {
                    let time = max(0, t - p.delay)
                    let y = -0.05 + time * p.speed + 0.25 * time * time * 0.4
                    guard y < 1.1 else { continue }
                    let x = p.x + p.drift * time + sin(time * 3 + p.x * 10) * 0.02
                    var c = ctx
                    c.translateBy(x: x * size.width, y: y * size.height)
                    c.rotate(by: .radians(p.spin * time))
                    c.opacity = max(0, 1 - max(0, t - 3))
                    c.fill(Path(roundedRect: CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2), cornerRadius: 1.5),
                           with: .color(colors[p.color % colors.count]))
                }
            }
        }
        .ignoresSafeArea()
    }
}
