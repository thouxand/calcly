import SwiftUI

/// The learning path: units with lessons on a winding road, like Duolingo.
struct PathView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var selected: Lesson?
    @State private var playing: Lesson?
    @State private var tips: Lesson?
    @State private var reviewing = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !store.state.mistakes.isEmpty {
                            Button { reviewing = true } label: {
                                HStack(spacing: 12) {
                                    Mascot(mood: .thinking, size: 40).frame(width: 50, height: 52)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Øv dine fejl")
                                            .font(.system(.headline, design: .rounded).weight(.heavy))
                                        Text("\(store.state.mistakes.count) \(store.state.mistakes.count == 1 ? "opgave" : "opgaver") venter")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.headline).foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .glassCard(22, tint: Color.heart.opacity(0.1), interactive: true)
                            }
                            .buttonStyle(PressStyle())
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                        }
                        ForEach(Course.units) { unit in
                            UnitBanner(unit: unit) { tips = unit.lessons.first }
                                .padding(.horizontal, 18)
                                .padding(.top, 26)
                                .padding(.bottom, 18)
                            ForEach(unit.lessons) { lesson in
                                node(lesson, unit: unit)
                                    .offset(x: CGFloat(sin(Double(globalIndex(lesson)) * 1.1)) * 78)
                                    .padding(.vertical, 12)
                                    .id(lesson.id)
                            }
                        }
                        Text("Mere kommer. Klarer du Mesterprøven, sidder det hele på rygraden.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(40)
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .background(AppBackground())
                .safeAreaInset(edge: .top) { StatsBar().padding(.horizontal, 16).padding(.bottom, 6) }
                .onAppear {
                    if let current = store.state.currentLesson {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.smooth) { proxy.scrollTo(current.id, anchor: .center) }
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selected) { lesson in
            LessonSheet(lesson: lesson, onStart: {
                selected = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { playing = lesson }
            }, onTips: {
                selected = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { tips = lesson }
            })
            .presentationDetents([.height(320)])
            .presentationCornerRadius(32)
        }
        .sheet(item: $tips) { lesson in TipsSheet(unit: Course.unit(of: lesson)) }
        .fullScreenCover(item: $playing) { lesson in LessonView(lesson: lesson) }
        .fullScreenCover(isPresented: $reviewing) {
            LessonView(lesson: Course.reviewLesson, review: Array(store.state.mistakes.shuffled().prefix(Course.exercisesPerLesson)))
        }
    }

    private func globalIndex(_ lesson: Lesson) -> Int { Course.lessons.firstIndex(of: lesson) ?? 0 }

    private func node(_ lesson: Lesson, unit: CourseUnit) -> some View {
        let unlocked = store.state.isUnlocked(lesson)
        let crowns = store.state.crowns(lesson)
        let current = store.state.currentLesson == lesson
        return Button { selected = lesson } label: {
            LessonNode(color: Color(hex: unit.colorHex), symbol: symbol(lesson, unit: unit),
                       unlocked: unlocked, crowns: crowns, current: current)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("\(lesson.title), \(unlocked ? "\(crowns) kroner" : "låst")")
    }

    private func symbol(_ lesson: Lesson, unit: CourseUnit) -> String {
        if lesson.id == "spine.master" { return "trophy.fill" }
        if lesson.id.hasSuffix("mix") || lesson.id.hasPrefix("spine") { return "star.fill" }
        return unit.symbol
    }
}

// MARK: - Pieces

struct StatsBar: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        let s = store.state
        HStack(spacing: 0) {
            stat("flame.fill", "\(s.currentStreak())", s.currentStreak() > 0 ? .flame : .secondary)
            Spacer()
            stat("bolt.fill", "\(s.xp)", .gold)
            Spacer()
            if s.useHearts {
                stat("heart.fill", "\(s.hearts)", .heart)
                Spacer()
            }
            GoalRing(progress: Double(s.xpToday()) / Double(max(1, s.dailyGoal)))
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .glassCapsule()
    }

    private func stat(_ symbol: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).contentTransition(.numericText())
        }
        .font(.system(.headline, design: .rounded).weight(.heavy))
    }
}

struct GoalRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(1, progress))
                .stroke(Color.good, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress >= 1 {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Color.good)
            }
        }
        .animation(.smooth, value: progress)
        .accessibilityLabel("Dagens mål \(Int(min(1, progress) * 100)) procent")
    }
}

private struct UnitBanner: View {
    let unit: CourseUnit
    let onTips: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.title)
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                Text(unit.subtitle)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.85)
            }
            Spacer()
            Button(action: onTips) {
                Image(systemName: "book.fill")
                    .font(.headline)
                    .frame(width: 46, height: 46)
                    .glassCircle(interactive: true)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Tips til \(unit.title)")
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(Color(hex: unit.colorHex).gradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .glassCard(26, tint: Color(hex: unit.colorHex).opacity(0.25))
        .shadow(color: Color(hex: unit.colorHex).opacity(0.35), radius: 14, y: 8)
    }
}

struct LessonNode: View {
    let color: Color
    let symbol: String
    let unlocked: Bool
    let crowns: Int
    let current: Bool
    @State private var bounce = false

    var body: some View {
        let fill = unlocked ? color : Color.gray.opacity(0.45)
        VStack(spacing: 6) {
            if current {
                Text("Start")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassCapsule()
                    .offset(y: bounce ? -5 : 0)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true }
                    }
            }
            ZStack {
                if crowns > 0 && crowns < ProgressState.maxCrowns {
                    Circle()
                        .trim(from: 0, to: Double(crowns) / Double(ProgressState.maxCrowns))
                        .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                }
                Circle()
                    .fill(fill.opacity(0.75))
                    .overlay(Circle().fill(.black.opacity(0.22)))
                    .frame(width: 76, height: 76)
                    .offset(y: 6)
                Circle()
                    .fill(fill.gradient)
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center))
                    }
                    .glassCircle(tint: unlocked ? color.opacity(0.3) : nil, interactive: true)
                Image(systemName: unlocked ? (crowns >= ProgressState.maxCrowns ? "crown.fill" : symbol) : "lock.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 100, height: 100)
            if crowns > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                    Text("\(crowns)")
                }
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color.gold)
            }
        }
    }
}

private struct LessonSheet: View {
    @EnvironmentObject private var store: ProgressStore
    let lesson: Lesson
    let onStart: () -> Void
    let onTips: () -> Void

    var body: some View {
        let unit = Course.unit(of: lesson)
        let color = Color(hex: unit?.colorHex ?? "#22C55E")
        let unlocked = store.state.isUnlocked(lesson)
        let crowns = store.state.crowns(lesson)
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(unit?.title ?? "")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .textCase(.uppercase)
                Text(lesson.title)
                    .font(.system(.title, design: .rounded).weight(.heavy))
                HStack(spacing: 4) {
                    ForEach(0..<ProgressState.maxCrowns, id: \.self) { i in
                        Image(systemName: "crown.fill").foregroundStyle(i < crowns ? Color.gold : Color.secondary.opacity(0.3))
                    }
                }
                .font(.subheadline)
            }
            if unlocked {
                Button(crowns == 0 ? "Start lektion" : crowns >= ProgressState.maxCrowns ? "Øv igen" : "Næste krone", action: onStart)
                    .buttonStyle(ChunkyButtonStyle(color: color))
                if store.state.useHearts && store.state.hearts == 0 {
                    Text("Du har ingen hjerter. Vent lidt, eller slå hjerter fra under Profil.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            } else {
                Text("Klar lektionen før for at låse op – eller slå \"Lås alt op\" til under Profil.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Se reglen", systemImage: "book.fill", action: onTips)
                .font(.headline)
                .tint(color)
        }
        .padding(24)
    }
}

/// The rules of a unit, lesson by lesson.
struct TipsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let unit: CourseUnit?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(unit?.lessons ?? []) { lesson in
                        VStack(spacing: 12) {
                            Text(lesson.title)
                                .font(.system(.headline, design: .rounded).weight(.heavy))
                                .foregroundStyle(Color(hex: unit?.colorHex ?? "#22C55E"))
                            MathText(markup: lesson.tip, size: 20, weight: .medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .glassCard()
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle(unit?.title ?? "Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Færdig") { dismiss() } } }
        }
    }
}
