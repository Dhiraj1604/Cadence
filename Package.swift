// swift-tools-version: 6.0

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Cadence",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "Cadence",
            targets: ["AppModule"],
            bundleIdentifier: "com.dhirajbodake.Cadence", // Your unique identifier
            teamIdentifier: "PUMDFHHYD3",                 // Your Apple Developer Team ID
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .mic),            // Fixed icon to prevent the crash
            accentColor: .presetColor(.mint),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                // These prevent the "abort with payload" privacy crashes
                .microphone(purposeString: "Cadence needs microphone access to analyze your speech volume and pacing in real-time."),
                .speechRecognition(purposeString: "Cadence uses speech recognition locally to track filler words and calculate your words-per-minute."),
                .camera(purposeString: "Cadence uses the camera entirely on-device to analyze your eye contact.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ],
    swiftLanguageModes: [.version("6")]
)
