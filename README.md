# Cadence
### *See the shape of your speech.*

Cadence is a real-time speech coaching app built entirely in Swift Playgrounds. It listens to how you speak — not just what you say — and turns your speaking patterns into a living visual fingerprint called **Speech Flow DNA**.

Built for the **Apple Swift Student Challenge 2026**. 🏆 Winner.

---

## The Problem

Most people don't know what they sound like when they speak.

You know the feeling: you finish a presentation, a job interview, a speech — and you can't tell if you spoke clearly or stumbled constantly. Standard feedback is vague ("speak more confidently") or comes after the fact. You can't improve what you can't see.

Filler words, unintended pauses, and moments of lost flow are invisible in the moment. Cadence makes them visible — in real time, as you speak.

---

## The Core Idea: Speech Flow DNA

Every speaking session in Cadence produces a **Speech Flow DNA** — a bar chart that maps your entire session, moment by moment, into four distinct states:

| State | What It Means |
|---|---|
| 🟢 **Confident** | Steady, clear speech — you're in flow |
| 🟡 **Filler** | "Um", "uh", "like", "you know" — verbal crutches |
| 🔴 **Lost Flow** | Fragmented or broken speech rhythm |
| ⚪ **Pause** | Intentional or unintentional silence |

The resulting visualization is unique to every session — a fingerprint of your speaking style. You can immediately see whether you spoke smoothly, where you lost confidence, and how often fillers crept in.

This is the central invention of Cadence: not a score, not a percentage — a **shape**. A shape that tells a story.

---

## Features

### 🎙️ Real-Time Speech Analysis
Live transcription and classification of your speech using Apple's Speech framework. Every word is analyzed as you speak — no post-processing delay.

### 📊 Speech Flow DNA Visualization
An animated bar chart that builds in real time as you speak. Each bar represents a classified speech moment. The full chart becomes your session's fingerprint.

### 👁️ Eye Contact Tracking
Uses the Vision framework to detect whether you're looking at your audience (the camera) or away. Displayed as a live percentage throughout your session.

### ⏱️ Filler Word Detection
Custom detection logic identifies common filler patterns — "um", "uh", "like", "you know", "so", and more — classified and tracked in real time.

### 📋 Session Summary
After each session, a full summary card shows:
- Speech Flow DNA chart for the session
- Total speaking time
- Filler word count
- Eye contact percentage
- Breakdown by speech state

### 🔁 Onboarding
A focused onboarding flow that explains what Cadence tracks and how to get the most out of a session.

---

## Technical Architecture

Cadence is built entirely in **Swift Playgrounds 4.6** using SwiftUI, with no external dependencies.

### Frameworks Used

| Framework | Purpose |
|---|---|
| `Speech` / `SFSpeechRecognizer` | Real-time transcription and speech detection |
| `AVFoundation` | Audio capture session management |
| `Vision` | Face and eye contact analysis via camera feed |
| `SwiftUI` | Entire UI — all views, animations, and transitions |
| `AppStorage` / `UserDefaults` | Onboarding state persistence |

### Key Components

```
Cadence.swiftpm/
├── App entry point
├── Onboarding flow
├── RecordView                  # Live session: mic + camera + real-time DNA chart
├── SpeechAnalysisEngine        # Core: classifies speech frames into 4 states
├── EyeContactTracker           # Vision-based gaze detection
├── FillerWordDetector          # Pattern matching on live transcript
├── SpeechFlowDNAView           # The bar chart visualization
└── SessionSummaryView          # Post-session results
```

### Speech Classification Logic

Each spoken segment is evaluated against a state machine:

1. Audio is captured via `AVAudioEngine`
2. `SFSpeechRecognizer` transcribes in real time with partial results
3. Transcription segments are checked for filler patterns
4. Silence thresholds determine pause classification
5. Coherent speech without fillers is classified as Confident
6. Fragmented transcription patterns trigger Lost Flow
7. Each classified frame appends a bar to the Speech Flow DNA chart

---

## Design Philosophy

Cadence is designed to feel like a native Apple app — not a third-party tool that happens to run on iOS.

**Principles applied:**

- **System colors only.** No custom brand palette. Every color is an iOS system color, ensuring the app adapts perfectly to light/dark mode and accessibility settings.
- **SF Symbols throughout.** Every icon is an SF Symbol — consistent weight, scale, and rendering with the OS.
- **Minimal UI surface.** The session view is almost entirely the DNA visualization. Nothing competes with your data.
- **One screen, one job.** Each view does exactly one thing. The record view records. The summary view summarizes.
- **No decoration.** Animations and transitions serve a function — they're not cosmetic.

This is a direct application of Apple Human Interface Guidelines: clarity, deference, and depth.

---

## Why This Exists

Communication is one of the most important skills a person can develop — and one of the hardest to improve without feedback.

Coaches are expensive. Recording yourself is uncomfortable. Reviewing footage is slow. Most speech apps give you a score and move on.

Cadence gives you a *picture*. A real-time, session-specific, visually distinctive picture of exactly how you spoke. That picture is faster to read, easier to compare across sessions, and more honest than a number.

The goal was never to build a speech app with more features. The goal was to build a new way of seeing your speech.

---

## About the Project

Cadence was created as a **Swift Student Challenge 2026** submission — built entirely in Swift Playgrounds, with no Xcode, no external packages, and no backend.

**Developer:** Dhiraj  
**Platform:** iPadOS / Swift Playgrounds 4.6  
**Status:** Award Winner — Swift Student Challenge 2026 (Top 350)

---

## Repository

> **Note:** This repository contains the full Swift Playgrounds package as submitted.

To run Cadence:
1. Open `Cadence.swiftpm` in Swift Playgrounds 4.6 or later on iPad or Mac
2. Grant microphone and speech recognition permissions when prompted
3. Grant camera permissions for eye contact tracking
4. Begin a session from the home screen

---

## License

This project is shared for educational and portfolio purposes.  
© 2026 Dhiraj. All rights reserved.
