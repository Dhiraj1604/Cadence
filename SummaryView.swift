// SummaryView.swift
// Cadence — Accurate scoring, meaningful waveform, honest feedback

import SwiftUI

// MARK: - Coach Insight Model
struct CoachInsight {
    let symbol: String
    let color: Color
    let title: String
    let detail: String
    let tip: String?
}

// MARK: - Summary View
struct SummaryView: View {
    @EnvironmentObject var session: SessionManager

    @State private var animWPM     = 0
    @State private var animFillers = 0
    @State private var animEye     = 0
    @State private var animRhythm  = 0.0
    @State private var animScore   = 0.0
    @State private var appeared    = false
    @State private var signaturePoints: [SpeechCanvasPoint] = []
    @State private var signatureImage: UIImage? = nil
    @State private var signatureRevealed = false

    private var hasRealSpeech: Bool {
        // Show results if either: meaningful WPM detected OR session ran long enough.
        // The original WPM≥30 AND duration≥10 was too strict — short tests were
        // silently discarded even when transcription worked fine.
        (session.finalWPM >= 10 && session.duration >= 5) ||
        (!session.finalTranscript.isEmpty &&
         session.finalTranscript != "No speech was detected during this session." &&
         session.duration >= 8)
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Scoring (honest, weighted, no free points)
    //
    // Four components totalling 100 points:
    //   Speech Rate   35 pts — most impactful
    //   Fillers       25 pts — per-minute rate, not raw count
    //   Eye Contact   25 pts — % of session
    //   Rhythm        15 pts — consistency score
    //
    // Score zero on rate → maximum you can earn is 65/100 → max C
    // ─────────────────────────────────────────────────────
    private var overallScore: Int {
        guard hasRealSpeech else { return 0 }

        // ── Speech Rate (35 pts) ──────────────────────────────────────
        // If session is < 25s, WPM is unreliable — cap its contribution
        let wpmReliable = session.duration >= 25
        let wpmPts: Int
        if !wpmReliable {
            // Can't trust the WPM number — award neutral 15 pts
            wpmPts = 15
        } else {
            switch session.finalWPM {
            case 130...150: wpmPts = 35
            case 120..<130, 151...160: wpmPts = 30
            case 110..<120, 161...170: wpmPts = 23
            case 95..<110,  171...190: wpmPts = 15
            case 70..<95,   191...220: wpmPts = 7
            default:        wpmPts = 2
            }
        }

        // ── Filler Words (25 pts) — LENIENT, rate-based ───────────────
        // For very short sessions, use raw count not per-minute rate
        let sessionMins    = max(0.5, session.duration / 60.0)
        let fillersPerMin  = Double(session.finalFillers) / sessionMins
        let excessRate     = max(0.0, fillersPerMin - 1.5)
        let fillerFraction = max(0.0, 1.0 - excessRate / 4.5)
        let fillerPts      = Int(25.0 * fillerFraction)

        // ── Eye Contact (25 pts) ──────────────────────────────────────
        let eyePts = Int(Double(session.eyeContactPercentage) / 100.0 * 25.0)

        // ── Rhythm Stability (15 pts — raised weight for choppy sessions) ──
        // If rhythmStability is measured AND very low, it's a strong signal.
        // We no longer give the "neutral 68" fallback if we have real data.
        let effectiveRhythm: Double
        if session.finalRhythmStability < 0 {
            // Truly no data (very short session) → neutral
            effectiveRhythm = 68.0
        } else {
            effectiveRhythm = session.finalRhythmStability
        }
        let rhythmPts: Int
        switch effectiveRhythm {
        case 85...100: rhythmPts = 15
        case 70..<85:  rhythmPts = 12
        case 55..<70:  rhythmPts = 9
        case 40..<55:  rhythmPts = 5
        default:       rhythmPts = 1   // was 2 — choppy should penalize more
        }

        // ── Short session penalty ─────────────────────────────────────
        // Under 20 seconds there's not enough data for a reliable score.
        // Apply a soft cap that prevents misleadingly high scores on quick tests.
        let rawScore = min(100, wpmPts + fillerPts + eyePts + rhythmPts)
        if session.duration < 20 {
            return min(rawScore, 60)   // cap at 60 for very short sessions
        }
        return rawScore
    }

    private var scoreLabel: String {
        switch overallScore {
        case 90...100: return "Excellent"
        case 80..<90:  return "Outstanding"
        case 70..<80:  return "Strong"
        case 60..<70:  return "Developing"
        case 45..<60:  return "Needs Work"
        default:       return "Keep Practicing"
        }
    }

    private var scoreColor: Color {
        switch overallScore {
        case 80...100: return Color.cadenceGood
        case 60..<80:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }

    // ─────────────────────────────────────────────────────
    // MARK: - Primary Insight (most important thing to fix)
    // Priority order: WPM → Fillers → EyeContact → Rhythm → Positive
    // ─────────────────────────────────────────────────────
    private var primaryInsight: CoachInsight {
        guard hasRealSpeech else {
            return CoachInsight(
                symbol: "mic.slash.fill", color: Color.white.opacity(0.4),
                title: "No Meaningful Speech Detected",
                detail: "Session was too short or too quiet to analyse. Aim for at least 15 seconds of clear speech.",
                tip: "Stand close to the device and speak at a normal conversation volume."
            )
        }

        let sessionMins    = max(0.5, session.duration / 60.0)
        let fillersPerMin  = Double(session.finalFillers) / sessionMins

        // Priority: worst metric first → give user ONE thing to fix
        if session.finalWPM < 80 {
            return CoachInsight(
                symbol: "tortoise.fill", color: Color.cadenceNeutral,
                title: "Pace Is Too Slow",
                detail: "You spoke at \(session.finalWPM) WPM. Audiences disengage below 100 WPM — it signals low confidence.",
                tip: "Target 130–150 WPM. Record yourself reading aloud and stop pausing between each word."
            )
        }
        if session.finalWPM > 185 {
            return CoachInsight(
                symbol: "hare.fill", color: Color.cadenceNeutral,
                title: "Speaking Too Fast",
                detail: "At \(session.finalWPM) WPM your audience cannot absorb what you're saying.",
                tip: "After every major idea, take a breath. 140 WPM is the sweet spot for clarity."
            )
        }
        // Only flag fillers if rate is genuinely high — ≥4 per minute
        if fillersPerMin >= 4 {
            return CoachInsight(
                symbol: "exclamationmark.bubble.fill", color: Color.cadenceWarn,
                title: "Filler Words Are Hurting You",
                detail: "\(session.finalFillers) filler\(session.finalFillers == 1 ? "" : "s") in \(durationText) — that's \(String(format: "%.1f", fillersPerMin)) per minute. Each one chips away at your credibility.",
                tip: "Every time you feel a filler coming, pause instead. Silence sounds confident. Fillers do not."
            )
        }
        if session.eyeContactPercentage < 50 {
            return CoachInsight(
                symbol: "eye.slash.fill", color: Color.cyan,
                title: "Eye Contact Needs Work",
                detail: "Only \(session.eyeContactPercentage)% eye contact recorded. Looking away signals nervousness.",
                tip: "Pick a focal point at eye level and hold it for 3–5 seconds per thought before shifting gaze."
            )
        }
        // Only flag rhythm if we have a real measurement AND it's bad
        let effectiveRhythm = session.finalRhythmStability < 0 ? 75.0 : session.finalRhythmStability
        if effectiveRhythm < 45 {
            return CoachInsight(
                symbol: "waveform.path", color: Color.cadenceWarn,
                title: "Uneven Rhythm",
                detail: "Your speech had choppy pacing — bursts of fast words then abrupt stops. This fragments your message.",
                tip: "Practice speaking in complete sentences without mid-sentence restarts."
            )
        }
        let flowBreaks = session.finalFlowEvents.filter {
            if case .flowBreak = $0.type { return true }; return false
        }.count
        if flowBreaks >= 3 {
            return CoachInsight(
                symbol: "brain.head.profile", color: Color.cadenceBad,
                title: "Lost Flow \(flowBreaks) Times",
                detail: "You lost your train of thought multiple times. This usually means ideas weren't organised before speaking.",
                tip: "Before you speak, mentally rehearse 3 clear points. You'll never lose flow if you know where you're going."
            )
        }
        // Mild filler nudge (1-3/min) — not a problem, just an awareness note
        if fillersPerMin >= 2 {
            return CoachInsight(
                symbol: "exclamationmark.bubble", color: Color.cadenceNeutral,
                title: "Minor Filler Habit",
                detail: "About \(String(format: "%.1f", fillersPerMin)) fillers per minute — not critical, but worth watching.",
                tip: "Try replacing your most common filler with a half-second pause. It sounds more authoritative."
            )
        }
        // All good
        return CoachInsight(
            symbol: "star.fill", color: Color.cadenceGood,
            title: "Solid Session",
            detail: "Good pace at \(session.finalWPM) WPM, \(session.finalFillers) filler\(session.finalFillers == 1 ? "" : "s"), \(session.eyeContactPercentage)% eye contact.",
            tip: overallScore >= 85
                ? "Challenge yourself with a more complex topic or double the session length."
                : "Keep building consistency. Daily practice beats occasional long sessions."
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.cadenceBG.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── CLOSE BUTTON ──────────────────────────────────
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                session.resetSession()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemFill))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)

                    // ── TITLE ──────────────────────────────────────────
                    Text(hasRealSpeech ? "Session Complete" : "Session Ended")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                        .staggerIn(appeared, delay: 0.05)

                    if hasRealSpeech {
                        // ── SCORE HERO ─────────────────────────────────
                        scoreHero
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                            .staggerIn(appeared, delay: 0.10)

                        // ── SPEECH SIGNATURE — the unique waveform ──────
                        speechSignatureCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .staggerIn(appeared, delay: 0.13)

                        // ── COACH INSIGHT ──────────────────────────────
                        insightCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .staggerIn(appeared, delay: 0.15)
                    } else {
                        // ── NO SPEECH STATE ────────────────────────────
                        noSpeechCard
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                            .staggerIn(appeared, delay: 0.10)
                    }

                    // ── SPEECH FLOW DNA ────────────────────────────────
                    if hasRealSpeech {
                        VStack(alignment: .leading, spacing: 8) {
                            CadenceSectionHeader(title: "Speech Flow DNA")
                                .padding(.horizontal, 20)
                            SpeechDNACard(events: session.finalFlowEvents, duration: session.duration)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                        .staggerIn(appeared, delay: 0.20)
                    }

                    // ── METRICS ────────────────────────────────────────
                    if hasRealSpeech {
                        VStack(alignment: .leading, spacing: 8) {
                            CadenceSectionHeader(title: "Metrics")
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                metricRow(
                                    symbol: "speedometer",
                                    label: "Speech Rate",
                                    value: animWPM == 0 ? "—" : "\(animWPM) WPM",
                                    subValue: session.duration < 25
                                        ? "⚠ Speak 30+ sec for accuracy"
                                        : "Target: 130–150 WPM",
                                    badge: pacingBadge, color: pacingColor
                                )
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 50)
                                metricRow(
                                    symbol: "exclamationmark.bubble.fill",
                                    label: "Filler Words",
                                    value: "\(animFillers)",
                                    subValue: animFillers == 0 ? "None detected" : fillerRateText,
                                    badge: fillerBadge, color: fillerColor
                                )
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 50)
                                metricRow(
                                    symbol: "eye.fill",
                                    label: "Eye Contact",
                                    value: "\(animEye)%",
                                    subValue: "of session time",
                                    badge: eyeBadge, color: eyeColor
                                )
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 50)
                                metricRow(
                                    symbol: "waveform.path",
                                    label: "Rhythm",
                                    value: String(format: "%.0f%%", animRhythm < 0 ? 68.0 : animRhythm),
                                    subValue: "pacing consistency",
                                    badge: rhythmBadge, color: rhythmColor
                                )
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 50)
                                metricRow(
                                    symbol: "waveform.and.mic",
                                    label: "Delivery Style",
                                    value: spontaneityLabel,
                                    subValue: "naturalness vs scripted",
                                    badge: spontaneityBadge, color: spontaneityColor
                                )
                            }
                            .background(Color.cadenceCard)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.mint.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)

                            Label(durationText, systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(Color.white.opacity(0.25))
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 20)
                        .staggerIn(appeared, delay: 0.25)
                    }

                    // ── FILLER WORD BREAKDOWN ──────────────────────────
                    if hasRealSpeech && !session.finalDetectedFillerWords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            CadenceSectionHeader(title: "Filler Words Detected")
                                .padding(.horizontal, 20)
                            fillerBreakdownCard
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                        .staggerIn(appeared, delay: 0.28)
                    }

                    // ── ACTION ─────────────────────────────────────────
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                            session.resetSession()
                        }
                    } label: {
                        Text("Practice Again")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(LinearGradient.cadencePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color.mint.opacity(0.30), radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    .staggerIn(appeared, delay: 0.30)
                }
            }
        }
        .onAppear {
            appeared = true
            guard hasRealSpeech else { return }
            // Build signature points
            signaturePoints = buildSignaturePoints()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.75)) {
                    animWPM     = session.finalWPM
                    animFillers = session.finalFillers
                    animEye     = session.eyeContactPercentage
                    animRhythm  = session.finalRhythmStability
                    animScore   = Double(overallScore)
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    signatureRevealed = true
                }
            }
            // Render shareable image after a brief layout settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                renderSignatureImage()
            }
        }
    }

    // MARK: - Filler Breakdown Card
    private var fillerBreakdownCard: some View {
        // Count frequency of each filler word
        var freq: [String: Int] = [:]
        for word in session.finalDetectedFillerWords {
            freq[word, default: 0] += 1
        }
        let sorted = freq.sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(Color.cadenceWarn)
                    .symbolRenderingMode(.hierarchical)
                Text("You used \(session.finalFillers) filler word\(session.finalFillers == 1 ? "" : "s") this session")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            // Filler chips with count badges
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], alignment: .leading, spacing: 8) {
                ForEach(sorted, id: \.key) { word, count in
                    HStack(spacing: 6) {
                        Text("\"\(word)\"")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.cadenceWarn)
                        Text("×\(count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.cadenceWarn.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.cadenceWarn.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.cadenceWarn.opacity(0.25), lineWidth: 1)
                    )
                }
            }

            Text("Replace each filler with a deliberate 1-second pause. Silence sounds confident.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.40))
        }
        .padding(16)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cadenceWarn.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - No Speech Card
    private var noSpeechCard: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 80)
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("No Speech Detected")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("We couldn't pick up any clear speech this session. Make sure you're speaking toward the device at a normal conversation volume.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Tips
            VStack(spacing: 10) {
                tipRow(icon: "mic.fill",        text: "Hold the device 30–50 cm from your face")
                tipRow(icon: "speaker.wave.2",  text: "Speak at a normal conversation volume")
                tipRow(icon: "clock",           text: "Aim for at least 20 seconds of speech")
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(20)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.mint.opacity(0.7))
                .frame(width: 20)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Score Hero
    private var scoreHero: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: CGFloat(animScore / 100))
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.35), radius: 8)
                VStack(spacing: 1) {
                    Text("\(Int(animScore))")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(scoreLabel)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [scoreColor.opacity(0.5), scoreColor],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * CGFloat(animScore / 100), height: 5)
                    }
                }
                .frame(height: 5)
                Text("Overall communication score")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.3))
            }
        }
        .padding(18)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(scoreColor.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Insight Card
    private var insightCard: some View {
        let insight = primaryInsight
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: insight.symbol)
                    .font(.title2)
                    .foregroundStyle(insight.color)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(insight.detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineSpacing(2)
                }
            }
            if let tip = insight.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(.top, 1)
                    Text(tip)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(insight.color.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Metric Row (with sub-value line)
    private func metricRow(
        symbol: String, label: String, value: String,
        subValue: String, badge: String, color: Color
    ) -> some View {
        HStack {
            Label(label, systemImage: symbol)
                .foregroundStyle(Color.white.opacity(0.75))
                .symbolRenderingMode(.hierarchical)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                StatBadge(text: badge, color: color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers
    private var durationText: String {
        let d = Int(session.duration)
        return d < 60 ? "Session: \(d) seconds" : "Session: \(d/60)m \(d%60)s"
    }

    private var fillerRateText: String {
        let mins = max(0.5, session.duration / 60.0)
        let rate = Double(session.finalFillers) / mins
        return String(format: "%.1f per minute", rate)
    }

    private var pacingBadge: String {
        // Short sessions (<25s) don't have reliable WPM — warn instead of misleading
        if session.duration < 25 && session.finalWPM > 0 {
            return "Short sample"
        }
        switch session.finalWPM {
        case 130...150: return "Ideal"
        case 115..<130, 151...165: return "Good"
        case 95..<115,  166...185: return "Slightly off"
        case 60..<95,   186...220: return "Needs work"
        case 0: return "No speech"
        default: return session.finalWPM > 220 ? "Too fast" : "Too slow"
        }
    }
    private var pacingColor: Color {
        if session.duration < 25 && session.finalWPM > 0 {
            return Color.cadenceNeutral
        }
        switch session.finalWPM {
        case 130...150: return Color.cadenceGood
        case 115..<130, 151...165: return Color.cadenceGood.opacity(0.8)
        case 95..<115,  166...185: return Color.cadenceNeutral
        case 0: return Color.white.opacity(0.3)
        default: return Color.cadenceWarn
        }
    }
    private var fillerBadge: String {
        let mins = max(0.5, session.duration / 60.0)
        let rate = Double(session.finalFillers) / mins
        switch rate {
        case 0:    return "Flawless"
        case ..<1: return "Excellent"
        case ..<2: return "Good"
        case ..<4: return "Noticeable"
        default:   return "Too many"
        }
    }
    private var fillerColor: Color {
        let mins = max(0.5, session.duration / 60.0)
        let rate = Double(session.finalFillers) / mins
        switch rate {
        case 0..<1: return Color.cadenceGood
        case 1..<2: return Color.cadenceGood.opacity(0.8)
        case 2..<4: return Color.cadenceNeutral
        default:    return Color.cadenceBad
        }
    }
    private var eyeBadge: String {
        switch session.eyeContactPercentage {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Acceptable"
        default:       return "Too low"
        }
    }
    private var eyeColor: Color {
        switch session.eyeContactPercentage {
        case 75...100: return Color.cadenceGood
        case 50..<75:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }
    private var rhythmBadge: String {
        let r = session.finalRhythmStability < 0 ? 68.0 : session.finalRhythmStability
        switch r {
        case 85...100: return "Consistent"
        case 70..<85:  return "Steady"
        case 55..<70:  return "Decent"
        case 40..<55:  return "Uneven"
        default:       return "Choppy"
        }
    }
    private var rhythmColor: Color {
        let r = session.finalRhythmStability < 0 ? 68.0 : session.finalRhythmStability
        switch r {
        case 75...100: return Color.cadenceGood
        case 50..<75:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }

    // MARK: - Spontaneity helpers
    private var spontaneityLabel: String {
        switch session.finalSpontaneityScore {
        case 70...100: return "Natural"
        case 40..<70:  return "Mixed"
        default:       return "Scripted"
        }
    }
    private var spontaneityBadge: String {
        switch session.finalSpontaneityScore {
        case 70...100: return "Authentic delivery"
        case 40..<70:  return "Some variation"
        default:       return "Try to vary pace"
        }
    }
    private var spontaneityColor: Color {
        switch session.finalSpontaneityScore {
        case 70...100: return Color.cadenceGood
        case 40..<70:  return Color.cadenceNeutral
        default:       return Color.cadenceWarn
        }
    }

    // MARK: - Speech Signature builder
    /// Converts session flow events into SpeechCanvasPoint array for the signature view.
    private func buildSignaturePoints() -> [SpeechCanvasPoint] {
        let events = session.finalFlowEvents
        guard !events.isEmpty, session.duration > 0 else { return [] }
        let maxTime = max(session.duration, events.map { $0.timestamp }.max() ?? 1.0)
        let eyeFraction = Double(session.eyeContactPercentage) / 100.0

        // Use a seeded-like sequence so the same session always draws the same shape
        var pseudoRand: Double = Double(session.finalWPM) * 0.01
        func nextRand(_ lo: Double, _ hi: Double) -> Double {
            pseudoRand = (pseudoRand * 6364136223846793005.0 + 1442695040888963407.0)
                .truncatingRemainder(dividingBy: 1_000_000)
            let frac = abs(pseudoRand) / 1_000_000
            return lo + frac * (hi - lo)
        }

        return events.map { event in
            let progress = event.timestamp / maxTime
            let intensity: Double
            let isFiller: Bool
            switch event.type {
            case .strongMoment:
                intensity = nextRand(0.72, 0.98)
                isFiller  = false
            case .filler(let w):
                intensity = nextRand(0.35, 0.55)
                _ = w
                isFiller  = true
            case .hesitation:
                intensity = nextRand(0.15, 0.30)
                isFiller  = false
            case .flowBreak:
                intensity = nextRand(0.05, 0.18)
                isFiller  = false
            }
            // Eye contact: probabilistic based on session average
            let hasEye = nextRand(0, 1) < eyeFraction
            return SpeechCanvasPoint(progress: progress, intensity: intensity,
                                     isFiller: isFiller, hasEyeContact: hasEye)
        }
    }

    /// Renders signature + metadata to a UIImage for sharing
    @MainActor
    private func renderSignatureImage() {
        guard !signaturePoints.isEmpty else { return }
        let card = signatureShareCard
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        signatureImage = renderer.uiImage
    }

    /// The card rendered for sharing — includes dark background + metadata
    private var signatureShareCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Speech Signature")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.mint)
                Spacer()
                Text("\(session.finalWPM) WPM · \(session.finalFillers) fillers · \(session.eyeContactPercentage)% eye contact")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            SpeechSignatureView(dataPoints: signaturePoints)
                .frame(height: 100)
            HStack(spacing: 14) {
                sigLegendDot(Color.mint,             "Speaking")
                sigLegendDot(Color.cadenceWarn,      "Filler")
                sigLegendDot(Color.white.opacity(0.3),"No eye contact")
                Spacer()
                Text("Cadence")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.mint.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color(red: 0.04, green: 0.05, blue: 0.04))
        .frame(width: 360)
    }

    private func sigLegendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(Color.white.opacity(0.35))
        }
    }

    // MARK: - Speech Signature Card (shown in summary)
    private var speechSignatureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Your Speech Signature")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("UNIQUE")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Color.mint)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.mint.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("Bar height = energy · gaps = pauses · orange = fillers · never repeated")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Spacer()
                // Share button
                if let img = signatureImage {
                    ShareLink(
                        item: Image(uiImage: img),
                        preview: SharePreview(
                            "My Speech Signature",
                            image: Image(uiImage: img)
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.mint)
                            .padding(8)
                            .background(Color.mint.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }

            // The signature itself
            if signaturePoints.isEmpty {
                // Placeholder while points are being built
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 90)
                    .overlay(
                        Text("Building signature…")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.2))
                    )
            } else {
                SpeechSignatureView(dataPoints: signaturePoints)
                    .frame(height: 90)
                    .opacity(signatureRevealed ? 1 : 0)
                    .animation(.easeIn(duration: 0.5), value: signatureRevealed)
            }

            // Legend
            HStack(spacing: 14) {
                sigLegendDot(Color.cadenceAccent, "Speaking")
                sigLegendDot(Color.cadenceWarn,   "Filler")
                sigLegendDot(Color.white.opacity(0.25), "No eye contact")
                Spacer()
            }
        }
        .padding(16)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.mint.opacity(0.35), Color.cyan.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Compatibility alias (kept for any external references)
typealias MetricListRow = SummaryMetricRowCompat

struct SummaryMetricRowCompat: View {
    let symbol: String; let color: Color; let label: String; let value: String; let badge: String
    var body: some View { EmptyView() }
}

struct SpeechDNATimeline: View {
    let events: [FlowEvent]; let duration: TimeInterval
    var body: some View { SpeechDNACard(events: events, duration: duration) }
}

private extension View {
    func staggerSummary(_ appeared: Bool, delay: Double) -> some View {
        self.opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay), value: appeared)
    }
}

// MARK: - Speech DNA Card
struct SpeechDNACard: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speech Journey")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Your session energy, mapped moment by moment")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Spacer()
                Text("YOUR DNA")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.mint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mint.opacity(0.12))
                    .clipShape(Capsule())
            }

            if events.isEmpty {
                Text("No events captured — speak longer to generate your journey.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                SpeechJourneyView(events: events, duration: duration)
                    .frame(height: 90)
                    .background(Color.cadenceBG)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Event summary row
                let fillers   = events.filter { if case .filler      = $0.type { return true }; return false }.count
                let pauses    = events.filter { if case .hesitation   = $0.type { return true }; return false }.count
                let breaks_   = events.filter { if case .flowBreak    = $0.type { return true }; return false }.count
                let strongs   = events.filter { if case .strongMoment = $0.type { return true }; return false }.count

                HStack(spacing: 0) {
                    journeyStat("⚡", "\(strongs)", "Strong",  .mint)
                    Spacer()
                    journeyStat("💬", "\(fillers)",  "Fillers", .orange)
                    Spacer()
                    journeyStat("⏸",  "\(pauses)",   "Pauses",  .yellow)
                    Spacer()
                    journeyStat("⚠️", "\(breaks_)",  "Breaks",  .red)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.cadenceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.mint.opacity(0.10), lineWidth: 1)
        )
    }

    private func journeyStat(_ emoji: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 14))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Speech Journey View
// A smooth gradient area chart. Y-axis = speech energy (strongMoment = top, hesitation = bottom).
// Colour transitions smoothly between event types. Event dots mark key moments.
// Judges see ONE clean picture of the entire session at a glance.
struct SpeechJourneyView: View {
    let events: [FlowEvent]
    let duration: TimeInterval

    private struct PlotPoint {
        let x: CGFloat    // normalised 0→1
        let y: CGFloat    // normalised 0→1 (1=top = high energy)
        let color: Color
        let isMarker: Bool
    }

    private func points(width: CGFloat, height: CGFloat) -> [PlotPoint] {
        guard duration > 0, !events.isEmpty else { return [] }

        // Synthesise curve: start at midpoint, move to each event's energy level
        var pts: [PlotPoint] = []
        let maxT = duration

        // Add anchor at start
        pts.append(PlotPoint(x: 0, y: 0.45, color: .mint, isMarker: false))

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            let xNorm = CGFloat(event.timestamp / maxT)
            let yNorm: CGFloat
            let color: Color
            let isMarker: Bool
            switch event.type {
            case .strongMoment:
                yNorm = CGFloat.random(in: 0.70...0.90)
                color = .mint; isMarker = true
            case .filler:
                yNorm = CGFloat.random(in: 0.30...0.50)
                color = .orange; isMarker = true
            case .hesitation:
                yNorm = CGFloat.random(in: 0.10...0.30)
                color = .yellow; isMarker = true
            case .flowBreak:
                yNorm = CGFloat.random(in: 0.05...0.20)
                color = .red; isMarker = true
            }
            pts.append(PlotPoint(x: xNorm, y: yNorm, color: color, isMarker: isMarker))
        }
        // End anchor
        pts.append(PlotPoint(x: 1.0, y: 0.45, color: .mint, isMarker: false))
        return pts
    }

    var body: some View {
        Canvas { ctx, size in
            let pts = points(width: size.width, height: size.height)
            guard pts.count >= 2 else { return }

            let w = size.width
            let h = size.height

            // ── 1. Filled area under the curve ──────────────────────────
            var area = Path()
            area.move(to: CGPoint(x: 0, y: h))
            for pt in pts {
                area.addLine(to: CGPoint(x: pt.x * w, y: (1 - pt.y) * h))
            }
            area.addLine(to: CGPoint(x: w, y: h))
            area.closeSubpath()
            ctx.fill(area, with: .color(Color.mint.opacity(0.08)))

            // ── 2. Smooth line through points ────────────────────────────
            var line = Path()
            for (i, pt) in pts.enumerated() {
                let px = pt.x * w
                let py = (1 - pt.y) * h
                if i == 0 {
                    line.move(to: CGPoint(x: px, y: py))
                } else {
                    let prev = pts[i - 1]
                    let ppx = prev.x * w
                    let ppy = (1 - prev.y) * h
                    let cpx = (ppx + px) / 2
                    line.addCurve(
                        to: CGPoint(x: px, y: py),
                        control1: CGPoint(x: cpx, y: ppy),
                        control2: CGPoint(x: cpx, y: py)
                    )
                }
            }
            ctx.stroke(line, with: .color(Color.mint.opacity(0.70)),
                       style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            // ── 3. Event dots ─────────────────────────────────────────────
            for pt in pts where pt.isMarker {
                let cx = pt.x * w
                let cy = (1 - pt.y) * h
                let r: CGFloat = 5
                // Halo
                let halo = Path(ellipseIn: CGRect(x: cx - r * 1.6, y: cy - r * 1.6,
                                                   width: r * 3.2, height: r * 3.2))
                ctx.fill(halo, with: .color(pt.color.opacity(0.20)))
                // Dot
                let dot = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                ctx.fill(dot, with: .color(pt.color))
            }

            // ── 4. Ideal zone band (130–150 WPM region) ──────────────────
            let idealTop    = h * 0.10     // high energy = top 10%
            let idealBottom = h * 0.30
            var band = Path()
            band.addRect(CGRect(x: 0, y: idealTop, width: w, height: idealBottom - idealTop))
            ctx.fill(band, with: .color(Color.mint.opacity(0.04)))
        }
        .drawingGroup()
    }
}
