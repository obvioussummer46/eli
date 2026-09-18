import SwiftUI

/// The very first open: the app icon's satchel lands on the icon's blue,
/// its flap swings open, and three cards for Heute, Aufgaben and Plan fan
/// out of it. Then the wordmark, then a hand-off into whatever `RootView`
/// has underneath (the login on a fresh install).
///
/// Plays on every launch that has no working login yet — a fresh install,
/// and again after a sign-out. Once a session works, later launches keep
/// the quote placeholder: the intro says what the app *is*, which stops
/// needing saying the moment someone is inside.
///
/// Timeline at 1× (see the design canvas for the storyboard):
///
///     0 ms    satchel enters       spring 0.45 / 0.75
///     400 ms  flap opens           spring 0.55 / 0.85, −160° about x
///     650 ms  cards fan out        spring 0.5 / 0.7, staggered 80 ms
///     1200 ms wordmark + tagline   ease-out 350 ms, tagline +120 ms
///     1550 ms hold                 at least 350 ms; longer while the
///                                  session check is still running
///     1900 ms hand-off             `onFinished`, at most at 6 s
///
/// Any tap after 800 ms skips straight to the hand-off. With Reduce Motion
/// nothing rotates or fans: everything appears in its end position with a
/// crossfade and the hand-off comes at 1.5 s.
struct FirstLaunchIntroView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Called once, when the hand-off starts. The caller removes the view;
    /// its exit transition is the hand-off animation.
    let onFinished: () -> Void

    @State private var hasEntered = false
    @State private var isFlapOpen = false
    /// Past 90° the flap is physically behind the cards, so it changes
    /// z-order once at the midpoint of its swing.
    @State private var isFlapBehind = false
    @State private var cardsOut: [Bool] = [false, false, false]
    @State private var showsWordmark = false
    @State private var showsTagline = false
    @State private var isHolding = false
    @State private var startedAt = Date()
    @State private var isFinished = false

    /// Whether the intro should play: on every launch without a working
    /// login — never in screenshot mode, where the invented week must come
    /// up first.
    static var shouldPlay: Bool {
        guard !DemoMode.isActive else { return false }
        if let signedIn = Settings.hasSignedInIfKnown { return !signedIn }
        // Installs from before the flag existed: stored credentials or a
        // picked school are the only traces of their account — no greeting
        // for people who are already inside.
        return PortalKeychain.load() == nil && !Settings.hasPickedSchool
    }

    private static let stageTop = Color(red: 0x3F / 255, green: 0x90 / 255, blue: 1)
    private static let stageBottom = Color(red: 0x0A / 255, green: 0x5C / 255, blue: 0xD6 / 255)
    private static let cardInk = Color(red: 0x0A / 255, green: 0x2E / 255, blue: 0x6B / 255)

    private struct Card: Identifiable {
        let id: Int
        let symbol: String
        let label: String
        let offset: CGSize
        let rotation: Double
    }

    private static let cards: [Card] = [
        Card(id: 0, symbol: "sun.max", label: "Heute", offset: CGSize(width: -108, height: -186), rotation: -14),
        Card(id: 1, symbol: "checklist", label: "Aufgaben", offset: CGSize(width: 0, height: -214), rotation: 0),
        Card(id: 2, symbol: "calendar", label: "Plan", offset: CGSize(width: 108, height: -186), rotation: 14),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Self.stageTop, Self.stageBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                satchel
                    .scaleEffect(hasEntered ? 1 : 0.8)
                    .offset(y: hasEntered ? 0 : 12)
                    .opacity(hasEntered ? 1 : 0)

                Text("Ranzen")
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .padding(.top, 34)
                    .opacity(showsWordmark ? 1 : 0)
                    .offset(y: showsWordmark ? 0 : 12)

                Text("Schulportal Hessen. Auf dem Handy.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 8)
                    .opacity(showsTagline ? 1 : 0)
                    .offset(y: showsTagline ? 0 : 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Skippable — but not so early that a stray touch from the
            // home screen tap swallows the whole thing.
            guard Date().timeIntervalSince(startedAt) > 0.8 else { return }
            finish()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ranzen. Schulportal Hessen. Auf dem Handy.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Überspringen")
        .accessibilityAction { finish() }
        .task { await play() }
    }

    // MARK: - Drawing

    /// The icon's satchel, 220 pt on a 1024-unit grid.
    private var satchel: some View {
        ZStack {
            ForEach(Self.cards) { card in
                cardView(card)
                    .offset(cardsOut[card.id] ? card.offset : .zero)
                    .rotationEffect(.degrees(cardsOut[card.id] ? card.rotation : 0))
                    .zIndex(0)
            }

            SatchelBody()
                .fill(.white)
                .zIndex(1)

            flap
                .rotation3DEffect(.degrees(isFlapOpen ? -160 : 0),
                                  axis: (x: 1, y: 0, z: 0),
                                  anchor: UnitPoint(x: 0.5, y: 220.0 / 1024.0),
                                  perspective: 0.6)
                .zIndex(isFlapBehind ? -1 : 2)
        }
        .frame(width: 220, height: 220)
    }

    private var flap: some View {
        ZStack {
            SatchelFlap()
                .fill(Color(white: 0.79))
            SatchelFlapBand()
                .fill(Color(white: 0.90))
            Circle()
                .fill(.white)
                .frame(width: 156 * 220 / 1024, height: 156 * 220 / 1024)
                .position(x: 512 * 220 / 1024, y: 600 * 220 / 1024)
            Circle()
                .fill(Color(white: 0.66))
                .frame(width: 76 * 220 / 1024, height: 76 * 220 / 1024)
                .position(x: 512 * 220 / 1024, y: 610 * 220 / 1024)
        }
        .frame(width: 220, height: 220)
    }

    private func cardView(_ card: Card) -> some View {
        VStack {
            Image(systemName: card.symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Self.stageBottom)
                .frame(height: 34)
            Spacer(minLength: 0)
            Text(card.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Self.cardInk)
        }
        .padding(EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 96, height: 112)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(red: 4 / 255, green: 40 / 255, blue: 110 / 255).opacity(0.28), radius: 12, y: 10)
        // Starts inside the body, hidden behind it: card top at 70 of 220.
        .offset(y: 16)
        .offset(y: isHolding ? -3 : 0)
    }

    // MARK: - Timeline

    private func play() async {
        startedAt = Date()
        if reduceMotion {
            await playReduced()
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { hasEntered = true }
        guard await pause(until: 0.4) else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { isFlapOpen = true }
        guard await pause(until: 0.65) else { return }
        isFlapBehind = true
        // Aufgaben first — it is the tallest — then the two sides.
        for (index, cardID) in [1, 0, 2].enumerated() {
            guard await pause(until: 0.65 + Double(index) * 0.08) else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { cardsOut[cardID] = true }
        }
        guard await pause(until: 1.2) else { return }
        withAnimation(.easeOut(duration: 0.35)) { showsWordmark = true }
        guard await pause(until: 1.32) else { return }
        withAnimation(.easeOut(duration: 0.35)) { showsTagline = true }
        guard await pause(until: 1.9) else { return }
        guard await holdUntilReady(deadline: 6) else { return }
        finish()
    }

    private func playReduced() async {
        hasEntered = true
        isFlapOpen = true
        isFlapBehind = true
        cardsOut = [true, true, true]
        withAnimation(.easeOut(duration: 0.3)) { showsWordmark = true }
        guard await pause(until: 0.1) else { return }
        withAnimation(.easeOut(duration: 0.3)) { showsTagline = true }
        guard await pause(until: 1.5) else { return }
        guard await holdUntilReady(deadline: 6) else { return }
        finish()
    }

    /// The session check usually finishes inside the animation. When it
    /// does not, the cards bob until it does — or until the deadline, after
    /// which the quote placeholder underneath takes over the waiting.
    private func holdUntilReady(deadline: TimeInterval) async -> Bool {
        guard model.phase == .launching else { return true }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { isHolding = true }
        }
        while model.phase == .launching, Date().timeIntervalSince(startedAt) < deadline {
            guard await pause(for: 0.1) else { return false }
        }
        return true
    }

    /// Sleeps until `seconds` after the start; `false` once the view is gone.
    private func pause(until seconds: TimeInterval) async -> Bool {
        let remaining = seconds - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return !Task.isCancelled }
        return await pause(for: remaining)
    }

    private func pause(for seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            return true
        } catch {
            return false
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinished()
    }
}

// MARK: - Shapes, on the icon's 1024-unit grid

private func scaled(_ rect: CGRect) -> CGFloat {
    min(rect.width, rect.height) / 1024
}

/// Handle plus body — the white part of the icon.
private struct SatchelBody: Shape {
    func path(in rect: CGRect) -> Path {
        let s = scaled(rect)
        var path = Path()
        // The handle: a thick arc, drawn as a stroked path.
        var handle = Path()
        handle.move(to: CGPoint(x: 340 * s, y: 250 * s))
        handle.addCurve(to: CGPoint(x: 684 * s, y: 250 * s),
                        control1: CGPoint(x: 380 * s, y: 60 * s),
                        control2: CGPoint(x: 644 * s, y: 60 * s))
        path.addPath(handle.strokedPath(StrokeStyle(lineWidth: 96 * s, lineCap: .round)))
        path.addRoundedRect(in: CGRect(x: 140 * s, y: 220 * s, width: 740 * s, height: 680 * s),
                            cornerSize: CGSize(width: 150 * s, height: 150 * s),
                            style: .continuous)
        return path
    }
}

private struct SatchelFlap: Shape {
    func path(in rect: CGRect) -> Path {
        let s = scaled(rect)
        return Path(roundedRect: CGRect(x: 140 * s, y: 220 * s, width: 740 * s, height: 390 * s),
                    cornerSize: CGSize(width: 150 * s, height: 150 * s),
                    style: .continuous)
    }
}

/// The lighter strip along the flap's lower edge, clipped to the flap.
private struct SatchelFlapBand: Shape {
    func path(in rect: CGRect) -> Path {
        let s = scaled(rect)
        let flap = SatchelFlap().path(in: rect)
        let band = Path(CGRect(x: 140 * s, y: 530 * s, width: 740 * s, height: 80 * s))
        return flap.intersection(band)
    }
}

#Preview {
    FirstLaunchIntroView {}
        .environment(AppModel())
}
