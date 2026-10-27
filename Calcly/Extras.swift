import SwiftUI
import AVFoundation
import UserNotifications

// MARK: - Sounds

/// Short sound effects. They follow the silent switch and mix with music.
@MainActor
enum Sound: String {
    case correct, wrong, complete, flip

    private static var players: [Sound: AVAudioPlayer] = [:]
    private static var ready = false

    static func play(_ sound: Sound, enabled: Bool) {
        guard enabled else { return }
        if !ready {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            ready = true
        }
        if players[sound] == nil {
            let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
                ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Sounds")
            guard let url, let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.prepareToPlay()
            players[sound] = p
        }
        guard let p = players[sound] else { return }
        p.currentTime = 0
        p.play()
    }
}

// MARK: - Daily reminder

/// A gentle nudge at the chosen time, on the days you haven't practised yet.
enum Reminder {
    private static let prefix = "calcly.reminder."

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Plans the next week. Today is skipped when you've already earned XP.
    static func reschedule(_ state: ProgressState) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<8).map { prefix + "\($0)" })
        guard state.reminder else { return }
        let calendar = Calendar.current
        let now = Date()
        let messages = [
            "Fem minutter calculus? Din streak venter 🔥",
            "Kædereglen glemmer ikke sig selv. Tag en hurtig lektion!",
            "Cal savner dig ∫ – en lynrunde tager kun et minut.",
            "Hold rygraden stærk: øv et par regler i dag.",
        ]
        for day in 0..<8 {
            guard let date = calendar.date(byAdding: .day, value: day, to: now) else { continue }
            var when = calendar.dateComponents([.year, .month, .day], from: date)
            when.hour = state.reminderHour
            when.minute = state.reminderMinute
            guard let fire = calendar.date(from: when), fire > now else { continue }
            if day == 0 && state.xpToday() > 0 { continue }
            let content = UNMutableNotificationContent()
            content.title = state.currentStreak() > 0 ? "\(state.currentStreak()) dage i træk" : "Calcly"
            content.body = messages[day % messages.count]
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: prefix + "\(day)", content: content, trigger: trigger))
        }
    }
}

// MARK: - Mascot

/// Cal, the little integral sign who cheers you on.
struct Mascot: View {
    enum Mood { case happy, cheer, sad, thinking }
    var mood: Mood = .happy
    var size: CGFloat = 90
    @State private var bob = false
    @State private var blink = false

    var body: some View {
        ZStack {
            // Body: a soft green blob with a glass shine.
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#4ADE80"), Color(hex: "#16A34A")], startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size * 0.92)
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.35)).frame(width: size * 0.5, height: size * 0.12).padding(.top, size * 0.08)
                }
                .shadow(color: Color(hex: "#16A34A").opacity(0.4), radius: size * 0.12, y: size * 0.08)
            // The ∫ antenna.
            Text("∫")
                .font(.system(size: size * 0.42, weight: .black, design: .serif))
                .foregroundStyle(Color(hex: "#15803D"))
                .offset(x: size * 0.2, y: -size * 0.58)
                .rotationEffect(.degrees(mood == .cheer ? -12 : 8))
            face
        }
        .frame(width: size * 1.2, height: size * 1.3)
        .offset(y: bob ? -size * 0.05 : size * 0.02)
        .scaleEffect(mood == .cheer && bob ? 1.06 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: mood == .cheer ? 0.45 : 1.4).repeatForever(autoreverses: true)) { bob = true }
        }
        .task {
            // Blinks now and then; stops when Cal leaves the screen.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.5...4.5)))
                withAnimation(.easeInOut(duration: 0.08)) { blink = true }
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(.easeInOut(duration: 0.08)) { blink = false }
            }
        }
        .accessibilityHidden(true)
    }

    private var face: some View {
        VStack(spacing: size * 0.08) {
            HStack(spacing: size * 0.2) { eye; eye }
            mouth
                .stroke(Color(hex: "#14532D"), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                .frame(width: size * 0.3, height: size * 0.12)
        }
        .offset(y: size * 0.04)
    }

    private var eye: some View {
        ZStack {
            Ellipse().fill(.white).frame(width: size * 0.2, height: blink ? size * 0.03 : size * 0.24)
            if !blink {
                Circle().fill(Color(hex: "#14532D")).frame(width: size * 0.1)
                    .offset(x: mood == .thinking ? size * 0.04 : 0, y: mood == .sad ? size * 0.04 : (mood == .thinking ? -size * 0.04 : 0))
            }
        }
    }

    private var mouth: Path {
        Path { p in
            let w = size * 0.3, h = size * 0.12
            switch mood {
            case .happy, .cheer:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: h * (mood == .cheer ? 2.2 : 1.6)))
            case .sad:
                p.move(to: CGPoint(x: 0, y: h))
                p.addQuadCurve(to: CGPoint(x: w, y: h), control: CGPoint(x: w / 2, y: -h * 0.4))
            case .thinking:
                p.move(to: CGPoint(x: w * 0.2, y: h * 0.6))
                p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.4))
            }
        }
    }
}

/// Cal with a speech bubble.
struct MascotSays: View {
    let text: String
    var mood: Mascot.Mood = .happy
    var size: CGFloat = 64

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Mascot(mood: mood, size: size)
            Text(text)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassCard(18)
        }
    }
}
