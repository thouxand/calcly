import Foundation

/// How well a rule card is known (Leitner boxes 0–5). Higher boxes come back less often.
struct CardState: Codable, Equatable {
    var box = 0
    var due = Date.distantPast
}

/// Everything the app remembers. Saved as JSON.
struct ProgressState: Codable, Equatable {
    static func == (a: ProgressState, b: ProgressState) -> Bool {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return (try? e.encode(a)) == (try? e.encode(b))
    }

    static let maxHearts = 5
    static let heartRefill: TimeInterval = 30 * 60
    static let maxCrowns = 5
    /// Days until a card is shown again, by box.
    static let cardIntervals: [Double] = [0, 1, 2, 4, 8, 16]

    var xp = 0
    var streak = 0
    var bestStreak = 0
    var lastActiveDay: String?
    var dailyXP: [String: Int] = [:]
    var dailyGoal = 30
    var crowns: [String: Int] = [:]
    var hearts = maxHearts
    var heartsUpdated = Date()
    var useHearts = true
    var unlockAll = false
    var bestQuick = 0
    var cards: [String: CardState] = [:]
    var lessonsDone = 0
    var correctAnswers = 0
    var totalAnswers = 0
    /// Exercises answered wrong, for "Øv dine fejl".
    var mistakes: [Exercise] = []
    var perfectLessons = 0
    var badges: [String] = []
    /// The day a missed day was covered by the weekly streak freeze.
    var lastFreezeUsed: String?
    var sound = true
    var reminder = false
    var reminderHour = 19
    var reminderMinute = 0

    static let maxMistakes = 40

    init() {}

    /// Reads saved progress; anything missing (from an older version) keeps its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ProgressState()
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? d.xp
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? d.streak
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? d.bestStreak
        lastActiveDay = try c.decodeIfPresent(String.self, forKey: .lastActiveDay)
        dailyXP = try c.decodeIfPresent([String: Int].self, forKey: .dailyXP) ?? d.dailyXP
        dailyGoal = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? d.dailyGoal
        crowns = try c.decodeIfPresent([String: Int].self, forKey: .crowns) ?? d.crowns
        hearts = try c.decodeIfPresent(Int.self, forKey: .hearts) ?? d.hearts
        heartsUpdated = try c.decodeIfPresent(Date.self, forKey: .heartsUpdated) ?? d.heartsUpdated
        useHearts = try c.decodeIfPresent(Bool.self, forKey: .useHearts) ?? d.useHearts
        unlockAll = try c.decodeIfPresent(Bool.self, forKey: .unlockAll) ?? d.unlockAll
        bestQuick = try c.decodeIfPresent(Int.self, forKey: .bestQuick) ?? d.bestQuick
        cards = try c.decodeIfPresent([String: CardState].self, forKey: .cards) ?? d.cards
        lessonsDone = try c.decodeIfPresent(Int.self, forKey: .lessonsDone) ?? d.lessonsDone
        correctAnswers = try c.decodeIfPresent(Int.self, forKey: .correctAnswers) ?? d.correctAnswers
        totalAnswers = try c.decodeIfPresent(Int.self, forKey: .totalAnswers) ?? d.totalAnswers
        mistakes = (try? c.decodeIfPresent([Exercise].self, forKey: .mistakes)) ?? d.mistakes
        perfectLessons = try c.decodeIfPresent(Int.self, forKey: .perfectLessons) ?? d.perfectLessons
        badges = try c.decodeIfPresent([String].self, forKey: .badges) ?? d.badges
        lastFreezeUsed = try c.decodeIfPresent(String.self, forKey: .lastFreezeUsed)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
        reminder = try c.decodeIfPresent(Bool.self, forKey: .reminder) ?? d.reminder
        reminderHour = try c.decodeIfPresent(Int.self, forKey: .reminderHour) ?? d.reminderHour
        reminderMinute = try c.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? d.reminderMinute
    }

    // MARK: Days

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func dayKey(daysBefore n: Int, from date: Date, calendar: Calendar = .current) -> String {
        dayKey(calendar.date(byAdding: .day, value: -n, to: date) ?? date, calendar: calendar)
    }

    /// The streak as it stands today: it breaks if yesterday was skipped.
    func currentStreak(now: Date = Date()) -> Int {
        guard let last = lastActiveDay else { return 0 }
        if last == Self.dayKey(now) || last == Self.dayKey(daysBefore: 1, from: now) { return streak }
        // One missed day a week is covered by the streak freeze.
        if last == Self.dayKey(daysBefore: 2, from: now) && freezeAvailable(now: now) { return streak }
        return 0
    }

    /// The freeze comes back seven days after it was used.
    func freezeAvailable(now: Date = Date()) -> Bool {
        guard let used = lastFreezeUsed else { return true }
        return used <= Self.dayKey(daysBefore: 7, from: now)
    }

    /// True when the freeze is saving the streak right now (yesterday was missed).
    func freezeActive(now: Date = Date()) -> Bool {
        lastActiveDay == Self.dayKey(daysBefore: 2, from: now) && freezeAvailable(now: now) && streak > 0
    }

    func xpToday(now: Date = Date()) -> Int { dailyXP[Self.dayKey(now)] ?? 0 }

    /// XP per day for the last `days` days, oldest first.
    func recentXP(days: Int = 7, now: Date = Date()) -> [(day: String, xp: Int)] {
        (0..<days).reversed().map { n in
            let key = Self.dayKey(daysBefore: n, from: now)
            return (key, dailyXP[key] ?? 0)
        }
    }

    /// Adds XP and keeps the streak going. Returns true if this started or extended the streak today.
    @discardableResult
    mutating func addXP(_ amount: Int, now: Date = Date()) -> Bool {
        guard amount > 0 else { return false }
        xp += amount
        let today = Self.dayKey(now)
        dailyXP[today, default: 0] += amount
        // Keep the last two months of history.
        if dailyXP.count > 70 {
            let cutoff = Self.dayKey(daysBefore: 60, from: now)
            dailyXP = dailyXP.filter { $0.key >= cutoff }
        }
        guard lastActiveDay != today else { return false }
        if lastActiveDay == Self.dayKey(daysBefore: 1, from: now) {
            streak += 1
        } else if lastActiveDay == Self.dayKey(daysBefore: 2, from: now) && freezeAvailable(now: now) {
            lastFreezeUsed = Self.dayKey(daysBefore: 1, from: now)
            streak += 1
        } else {
            streak = 1
        }
        bestStreak = max(bestStreak, streak)
        lastActiveDay = today
        return true
    }

    // MARK: Hearts

    /// Gives back one heart for every half hour since the last change.
    mutating func refillHearts(now: Date = Date()) {
        guard hearts < Self.maxHearts else { heartsUpdated = now; return }
        let gained = Int(now.timeIntervalSince(heartsUpdated) / Self.heartRefill)
        guard gained > 0 else { return }
        hearts = min(Self.maxHearts, hearts + gained)
        heartsUpdated = hearts == Self.maxHearts ? now : heartsUpdated.addingTimeInterval(Double(gained) * Self.heartRefill)
    }

    mutating func loseHeart(now: Date = Date()) {
        refillHearts(now: now)
        if hearts == Self.maxHearts { heartsUpdated = now }
        hearts = max(0, hearts - 1)
    }

    /// Time until the next heart comes back, or nil when full.
    func nextHeart(now: Date = Date()) -> TimeInterval? {
        guard hearts < Self.maxHearts else { return nil }
        return max(0, Self.heartRefill - now.timeIntervalSince(heartsUpdated))
    }

    // MARK: Lessons

    func crowns(_ lesson: Lesson) -> Int { crowns[lesson.id] ?? 0 }

    func isUnlocked(_ lesson: Lesson) -> Bool {
        if unlockAll { return true }
        let all = Course.lessons
        guard let i = all.firstIndex(of: lesson) else { return false }
        return i == 0 || (crowns[all[i - 1].id] ?? 0) > 0
    }

    /// The first lesson not finished yet (where the path glows).
    var currentLesson: Lesson? {
        Course.lessons.first { (crowns[$0.id] ?? 0) == 0 && isUnlocked($0) }
    }

    mutating func completeLesson(_ lesson: Lesson) {
        crowns[lesson.id] = min(Self.maxCrowns, (crowns[lesson.id] ?? 0) + 1)
        lessonsDone += 1
    }

    mutating func recordAnswer(correct: Bool) {
        totalAnswers += 1
        if correct { correctAnswers += 1 }
    }

    // MARK: Mistakes

    private static func key(_ e: Exercise) -> String { e.prompt + "|" + e.question }

    mutating func addMistake(_ e: Exercise) {
        guard !mistakes.contains(where: { Self.key($0) == Self.key(e) }) else { return }
        mistakes.append(e)
        if mistakes.count > Self.maxMistakes { mistakes.removeFirst(mistakes.count - Self.maxMistakes) }
    }

    mutating func clearMistake(_ e: Exercise) {
        mistakes.removeAll { Self.key($0) == Self.key(e) }
    }

    // MARK: Badges

    /// Badges earned now that weren't before. They are recorded as earned.
    mutating func collectBadges() -> [Badge] {
        let new = Badge.all.filter { !badges.contains($0.id) && $0.earned(self) }
        badges += new.map(\.id)
        return new
    }

    // MARK: Rule cards

    func card(_ id: String) -> CardState { cards[id] ?? CardState() }

    /// Cards to go through now: those that are due, new ones last, at most `limit`.
    func dueCards(now: Date = Date(), limit: Int = 15) -> [RuleCard] {
        let due = Course.cards.filter { cards[$0.id] != nil && card($0.id).due <= now }
            .sorted { card($0.id).box < card($1.id).box }
        let new = Course.cards.filter { cards[$0.id] == nil }
        return Array((due + new).prefix(limit))
    }

    var masteredCards: Int { Course.cards.filter { card($0.id).box >= 4 }.count }

    mutating func grade(_ cardID: String, knew: Bool, now: Date = Date()) {
        var c = card(cardID)
        if knew {
            c.box = min(Self.cardIntervals.count - 1, c.box + 1)
            c.due = now.addingTimeInterval(Self.cardIntervals[c.box] * 86_400)
        } else {
            c.box = 0
            c.due = now
        }
        cards[cardID] = c
    }
}

/// Achievements shown on the profile.
struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let colorHex: String
    let earned: (ProgressState) -> Bool

    static let all: [Badge] = [
        Badge(id: "first", title: "Første skridt", detail: "Klar din første lektion", symbol: "figure.walk", colorHex: "#22C55E") { $0.lessonsDone >= 1 },
        Badge(id: "ten", title: "I gang", detail: "Klar 10 lektioner", symbol: "graduationcap.fill", colorHex: "#3B82F6") { $0.lessonsDone >= 10 },
        Badge(id: "fifty", title: "Flittig", detail: "Klar 50 lektioner", symbol: "books.vertical.fill", colorHex: "#6366F1") { $0.lessonsDone >= 50 },
        Badge(id: "perfect", title: "Fejlfri", detail: "En lektion uden fejl", symbol: "star.fill", colorHex: "#EAB308") { $0.perfectLessons >= 1 },
        Badge(id: "perfect10", title: "Skarpskytte", detail: "10 lektioner uden fejl", symbol: "target", colorHex: "#F97316") { $0.perfectLessons >= 10 },
        Badge(id: "streak3", title: "På vej", detail: "3 dage i træk", symbol: "flame", colorHex: "#FB923C") { $0.bestStreak >= 3 },
        Badge(id: "streak7", title: "En hel uge", detail: "7 dage i træk", symbol: "flame.fill", colorHex: "#F97316") { $0.bestStreak >= 7 },
        Badge(id: "streak30", title: "Uknuselig", detail: "30 dage i træk", symbol: "bolt.heart.fill", colorHex: "#EF4444") { $0.bestStreak >= 30 },
        Badge(id: "quick15", title: "Lynhurtig", detail: "15 point i Lynrunden", symbol: "bolt.fill", colorHex: "#EAB308") { $0.bestQuick >= 15 },
        Badge(id: "quick30", title: "Lynet", detail: "30 point i Lynrunden", symbol: "bolt.circle.fill", colorHex: "#CA8A04") { $0.bestQuick >= 30 },
        Badge(id: "cards10", title: "Hukommelse", detail: "10 kort sidder på rygraden", symbol: "brain.head.profile", colorHex: "#A855F7") { $0.masteredCards >= 10 },
        Badge(id: "cardsAll", title: "Rygraden", detail: "Alle kort sidder", symbol: "brain.fill", colorHex: "#7C3AED") { $0.masteredCards >= Course.cards.count },
        Badge(id: "crown5", title: "Kronjuvel", detail: "5 kroner i én lektion", symbol: "crown.fill", colorHex: "#EAB308") { $0.crowns.values.contains { $0 >= ProgressState.maxCrowns } },
        Badge(id: "course", title: "Hele kurset", detail: "Klar alle lektioner", symbol: "trophy.fill", colorHex: "#EAB308") { s in Course.lessons.allSatisfy { (s.crowns[$0.id] ?? 0) > 0 } },
    ]
}
