import SwiftUI
import Charts

struct ProfileView: View {
    @EnvironmentObject private var store: ProgressStore
    @State private var confirmReset = false
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    streakCard
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        stat("XP i alt", "\(store.state.xp)", "bolt.fill", .gold)
                        stat("Lektioner", "\(store.state.lessonsDone)", "graduationcap.fill", .blue)
                        stat("Præcision", accuracy, "target", .good)
                        stat("Kort på rygraden", "\(store.state.masteredCards)/\(Course.cards.count)", "rectangle.on.rectangle.angled", .purple)
                        stat("Lynrunde-rekord", "\(store.state.bestQuick)", "trophy.fill", .flame)
                        stat("Kroner", "\(store.state.crowns.values.reduce(0, +))", "crown.fill", .gold)
                    }
                    weekCard
                    settingsCard
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Profil")
            .confirmationDialog("Nulstil alt?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Nulstil", role: .destructive) { store.reset() }
            } message: {
                Text("XP, streak, kroner og kort starter forfra.")
            }
        }
    }

    private var accuracy: String {
        guard store.state.totalAnswers > 0 else { return "–" }
        return "\(Int((Double(store.state.correctAnswers) / Double(store.state.totalAnswers) * 100).rounded())) %"
    }

    private var streakCard: some View {
        let streak = store.state.currentStreak()
        return HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.system(size: 52))
                .foregroundStyle(streak > 0 ? Color.flame.gradient : Color.gray.gradient)
                .symbolEffect(.bounce, value: streak)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak) \(streak == 1 ? "dag" : "dage") i træk")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                Text(streak > 0 && store.state.xpToday() == 0 ? "Lav en lektion i dag for at holde den!" : "Bedste: \(store.state.bestStreak) dage")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .glassCard(tint: streak > 0 ? Color.flame.opacity(0.12) : nil)
    }

    private func stat(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.title3).foregroundStyle(tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(22)
    }

    private var weekCard: some View {
        let days = store.state.recentXP()
        let goal = store.state.dailyGoal
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Denne uge").font(.system(.headline, design: .rounded).weight(.heavy))
                Spacer()
                Text("Mål: \(goal) XP om dagen").font(.subheadline).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    BarMark(x: .value("Dag", weekday(i, of: days.count)), y: .value("XP", d.xp))
                        .foregroundStyle(d.xp >= goal ? Color.good.gradient : Color.accentColor.gradient)
                        .cornerRadius(6)
                }
                RuleMark(y: .value("Mål", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.secondary)
            }
            .frame(height: 170)
        }
        .padding(20)
        .glassCard()
    }

    /// "Man", "Tir" … with today last.
    private func weekday(_ i: Int, of count: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: i - (count - 1), to: Date()) ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "da_DK")
        f.dateFormat = "EEE"
        return f.string(from: date).capitalized.replacingOccurrences(of: ".", with: "")
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Indstillinger").font(.system(.headline, design: .rounded).weight(.heavy))
            HStack {
                Text("Dagligt mål")
                Spacer()
                Picker("Dagligt mål", selection: $store.state.dailyGoal) {
                    ForEach([10, 20, 30, 50, 80], id: \.self) { Text("\($0) XP").tag($0) }
                }
                .pickerStyle(.menu)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Udseende")
                Picker("Udseende", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Toggle(isOn: $store.state.useHearts) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hjerter")
                    Text("Du mister et hjerte, når du svarer forkert. Et nyt kommer hver halve time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $store.state.unlockAll) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lås alt op")
                    Text("Spring frem til det, du vil øve. Godt, hvis du kan det grundlæggende.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            Button("Nulstil fremskridt", role: .destructive) { confirmReset = true }
        }
        .tint(.good)
        .padding(20)
        .glassCard()
    }
}
