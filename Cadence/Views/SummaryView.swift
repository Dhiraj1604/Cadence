// SummaryView.swift
// Cadence — Apple-clean summary: score → insight → timeline → details

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
    
    // Collapsible detail sections
    @State private var showTranscript     = false
    @State private var showFillerDetail   = false
    @State private var showAllMetrics     = false
    
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
            Color(.systemBackground).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // ── CLOSE BUTTON ──────────────────────────────────
                    HStack {
                        Spacer()
                        FitnessNavButton(icon: "xmark", size: 34, iconSize: 15) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                session.resetSession()
                            }
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    
                    // ── TITLE ──────────────────────────────────────────
                    Text(hasRealSpeech ? "Session Complete" : "Session Ended")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .staggerIn(appeared, delay: 0.05)
                    
                    if hasRealSpeech {
                        // ── SECTION 1: SCORE HERO + KEY METRICS ────────
                        scoreHeroCard
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                            .staggerIn(appeared, delay: 0.10)
                        
                        // ── SECTION 2: COACH INSIGHT ───────────────────
                        insightCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .staggerIn(appeared, delay: 0.15)
                        
                        // ── SECTION 3: SESSION TIMELINE ────────────────
                        if !session.finalFlowEvents.isEmpty {
                            sessionTimelineCard
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                .staggerIn(appeared, delay: 0.20)
                        }
                        
                        // ── SECTION 4: COLLAPSIBLE DETAILS ─────────────
                        detailsSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .staggerIn(appeared, delay: 0.25)
                        
                    } else {
                        // ── NO SPEECH STATE ────────────────────────────
                        noSpeechCard
                            .padding(.top, 24)
                            .padding(.horizontal, 20)
                            .staggerIn(appeared, delay: 0.10)
                    }
                    
                    // ── ACTION ─────────────────────────────────────────
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                            session.resetSession()
                        }
                    } label: {
                        Text("Practice Again")
                    }
                    .buttonStyle(CadencePrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                    .staggerIn(appeared, delay: 0.30)
                }
            }
        }
        .onAppear {
            appeared = true
            guard hasRealSpeech else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.75)) {
                    animWPM     = session.finalWPM
                    animFillers = session.finalFillers
                    animEye     = session.eyeContactPercentage
                    animRhythm  = session.finalRhythmStability
                    animScore   = Double(overallScore)
                }
            }
        }
    }
    
    // MARK: - Score Hero Card (with inline key metrics)
    private var scoreHeroCard: some View {
        VStack(spacing: 20) {
            // Score ring + label
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
                    
                    // Duration label
                    Label(durationText, systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            
            // ── Inline key metrics (3-column) ─────────────────────
            HStack(spacing: 0) {
                inlineMetric(
                    value: animWPM == 0 ? "—" : "\(animWPM)",
                    label: "WPM",
                    badge: pacingBadge,
                    color: pacingColor
                )
                
                dividerBar
                
                inlineMetric(
                    value: "\(animFillers)",
                    label: "Fillers",
                    badge: fillerBadge,
                    color: fillerColor
                )
                
                dividerBar
                
                inlineMetric(
                    value: "\(animEye)%",
                    label: "Eye Contact",
                    badge: eyeBadge,
                    color: eyeColor
                )
            }
            .padding(.vertical, 4)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CadenceLayout.cardCornerRadius, style: .continuous))
    }
    
    /// A single inline metric column for the hero card
    private func inlineMetric(value: String, label: String, badge: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            StatBadge(text: badge, color: color)
        }
        .frame(maxWidth: .infinity)
    }
    
    /// Thin vertical divider between metric columns
    private var dividerBar: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 50)
    }
    
    // MARK: - Insight Card
    private var insightCard: some View {
        let insight = primaryInsight
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: insight.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(insight.color)
                    .frame(width: 32, height: 32)
                    .background(insight.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Text("Your #1 Focus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(insight.color)
                    .textCase(.uppercase)
            }
            
            Text(insight.title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(insight.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            
            if let tip = insight.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(.top, 1)
                    Text(tip)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.yellow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CadenceLayout.cardCornerRadius, style: .continuous))
    }
    
    // MARK: - Session Timeline Card
    private var sessionTimelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Timeline")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("How your session played out over time")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                Spacer()
            }
            
            SessionTimelineView(events: session.finalFlowEvents, duration: session.duration)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CadenceLayout.cardCornerRadius, style: .continuous))
    }
    
    // MARK: - Collapsible Details Section
    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Section header
            Text("DETAILS")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                // ── Transcript ─────────────────────────────────────
                if !session.finalTranscript.isEmpty &&
                   session.finalTranscript != "No speech was detected during this session." {
                    detailRow(
                        icon: "text.quote",
                        title: "Transcript",
                        isExpanded: $showTranscript
                    ) {
                        Text(session.finalTranscript)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                            .padding(.horizontal, 16)
                    }
                    
                    Divider().padding(.leading, 52)
                }
                
                // ── Filler Breakdown ───────────────────────────────
                if !session.finalDetectedFillerWords.isEmpty {
                    detailRow(
                        icon: "exclamationmark.bubble.fill",
                        title: "Filler Breakdown",
                        isExpanded: $showFillerDetail
                    ) {
                        fillerBreakdownContent
                            .padding(.top, 4)
                            .padding(.bottom, 12)
                            .padding(.horizontal, 16)
                    }
                    
                    Divider().padding(.leading, 52)
                }
                
                // ── All Metrics ────────────────────────────────────
                detailRow(
                    icon: "chart.bar.fill",
                    title: "All Metrics",
                    isExpanded: $showAllMetrics
                ) {
                    allMetricsContent
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                        .padding(.horizontal, 16)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: CadenceLayout.cardCornerRadius, style: .continuous))
        }
    }
    
    /// A single expandable detail row with disclosure chevron
    private func detailRow<Content: View>(
        icon: String,
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.cadenceAccent)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    /// Filler word chips shown inside the collapsible detail
    private var fillerBreakdownContent: some View {
        let words = session.finalDetectedFillerWords
        var freq: [String: Int] = [:]
        for word in words { freq[word, default: 0] += 1 }
        let sorted = freq.sorted { $0.value > $1.value }
        
        return VStack(alignment: .leading, spacing: 10) {
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
                }
            }
            
            Text("Replace each filler with a 1-second pause.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.35))
        }
    }
    
    /// Full metric breakdown shown inside the collapsible detail
    private var allMetricsContent: some View {
        VStack(spacing: 10) {
            metricDetailRow(
                icon: "speedometer",
                label: "Speech Rate",
                value: animWPM == 0 ? "—" : "\(animWPM) WPM",
                badge: pacingBadge,
                color: pacingColor,
                note: session.duration < 25 ? "⚠ Speak 30+ sec for accuracy" : "Target: 130–150 WPM"
            )
            metricDetailRow(
                icon: "exclamationmark.bubble.fill",
                label: "Filler Words",
                value: "\(animFillers)",
                badge: fillerBadge,
                color: fillerColor,
                note: animFillers == 0 ? "None detected" : fillerRateText
            )
            metricDetailRow(
                icon: "eye.fill",
                label: "Eye Contact",
                value: "\(animEye)%",
                badge: eyeBadge,
                color: eyeColor,
                note: "of session time"
            )
            metricDetailRow(
                icon: "waveform.path",
                label: "Rhythm",
                value: String(format: "%.0f%%", animRhythm < 0 ? 68.0 : animRhythm),
                badge: rhythmBadge,
                color: rhythmColor,
                note: "pacing consistency"
            )
            metricDetailRow(
                icon: "waveform.and.mic",
                label: "Delivery Style",
                value: spontaneityLabel,
                badge: spontaneityBadge,
                color: spontaneityColor,
                note: "naturalness vs scripted"
            )
        }
    }
    
    private func metricDetailRow(icon: String, label: String, value: String,
                                  badge: String, color: Color, note: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                StatBadge(text: badge, color: color)
            }
        }
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
        .cadenceCard()
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
    
    // MARK: - Helpers
    private var durationText: String {
        let d = Int(session.duration)
        return d < 60 ? "\(d)s" : "\(d/60)m \(d%60)s"
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
}

// MARK: - Compatibility aliases (kept for any external references)
typealias MetricListRow = SummaryMetricRowCompat

struct SummaryMetricRowCompat: View {
    let symbol: String; let color: Color; let label: String; let value: String; let badge: String
    var body: some View { EmptyView() }
}

struct SpeechDNATimeline: View {
    let events: [FlowEvent]; let duration: TimeInterval
    var body: some View { EmptyView() }
}

private extension View {
    func staggerSummary(_ appeared: Bool, delay: Double) -> some View {
        self.opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(delay), value: appeared)
    }
}
