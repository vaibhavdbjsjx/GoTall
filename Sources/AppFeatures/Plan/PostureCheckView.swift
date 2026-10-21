#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// The 30-second posture check: choose front or side, stand back so the camera sees you from head to hips,
/// hold still for a 3-second reading, then see a score, what it found and the routines that help.
struct PostureCheckView: View {
    let repository: AppRepository
    let profile: GrowthProfile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @StateObject private var camera = PostureCamera()

    enum Stage: Equatable {
        case choose
        case framing
        case countdown(Int)
        case reading
        case result
    }

    @State private var view: PostureView = .front
    @State private var stage: Stage = .choose
    @State private var samples: [BodyLandmarks] = []
    @State private var result: PostureResult?
    @State private var steadyFrames = 0
    @State private var playingRoutine: Routine?
    @State private var tick = 0

    var body: some View {
        NavigationStack {
            ZStack {
                PageBackdrop()
                switch stage {
                case .choose: chooseView
                case .framing, .countdown, .reading: cameraView
                case .result: resultView
                }
            }
            .animation(Motion.resolved(Motion.page, reduceMotion: reduceMotion), value: stage)
            .navigationTitle("Posture check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sensoryFeedback(.impact(weight: .light), trigger: tick)
            .onChange(of: camera.landmarks) { _, landmarks in handle(landmarks) }
            .onDisappear { camera.stop() }
            .onAppear {
                #if DEBUG
                // Screenshot harness: `-openPostureDemo YES` shows a result from fixed landmarks (simulators have no camera).
                if UserDefaults.standard.bool(forKey: "openPostureDemo"), result == nil {
                    let demo = BodyLandmarks(nose: BodyPoint(x: 0.5, y: 0.82), leftEar: BodyPoint(x: 0.56, y: 0.83), rightEar: BodyPoint(x: 0.44, y: 0.825),
                                             leftShoulder: BodyPoint(x: 0.66, y: 0.70), rightShoulder: BodyPoint(x: 0.34, y: 0.685),
                                             leftHip: BodyPoint(x: 0.6, y: 0.42), rightHip: BodyPoint(x: 0.4, y: 0.415))
                    result = PostureScoring.front(demo)
                    stage = .result
                }
                #endif
            }
            .fullScreenCover(item: $playingRoutine) { routine in
                RoutinePlayerView(routine: routine, repository: repository, profileID: profile.id)
            }
        }
    }

    // MARK: Choose

    private var chooseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Stand where your phone can see you from head to hips, about two metres away. Prop it up at chest height.")
                    .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                SelectionCard(title: "Front view", detail: "Checks whether your head, shoulders and hips are level.",
                              systemImage: "figure.stand", isSelected: view == .front) { view = .front }
                SelectionCard(title: "Side view", detail: "Checks whether your head sits forward of your shoulders (tech neck).",
                              systemImage: "figure.walk", isSelected: view == .side) { view = .side }
                PrivacyNotice(items: [(symbol: "lock.shield", title: "Private by design",
                                       detail: "The camera image is analysed on this iPhone and never saved or sent. Only the angles are kept.")])
                AppButton("Start camera", systemImage: "camera") {
                    stage = .framing
                    camera.start()
                }
                .accessibilityIdentifier("posture.start")
            }
            .padding(DS.Spacing.page)
        }
    }

    // MARK: Camera

    private var cameraView: some View {
        ZStack {
            switch camera.status {
            case .denied:
                ErrorStateView(title: "Camera access is off", message: "Allow camera access in Settings to use the posture check. Nothing is recorded.",
                               primaryTitle: "Open Settings", primaryAction: {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                })
            case .unavailable:
                ErrorStateView(title: "No camera available", message: "The posture check needs the front camera of an iPhone.",
                               primaryTitle: "Close", primaryAction: { dismiss() })
            default:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                PostureOverlay(landmarks: camera.landmarks, frameSize: camera.frameSize)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    guidance
                        .padding(DS.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .padding(DS.Spacing.page)
                }
                if case .countdown(let n) = stage {
                    Text("\(n)")
                        .font(.system(size: 120, weight: .light, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(radius: 12)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("Starting in \(n)")
                }
            }
        }
    }

    @ViewBuilder
    private var guidance: some View {
        switch stage {
        case .reading:
            HStack(spacing: DS.Spacing.sm) {
                ProgressView().tint(DS.Colors.accent)
                Text("Hold still… reading your posture").font(DS.Typography.headline).foregroundStyle(.white)
            }
        case .countdown:
            Text("Stand naturally and look straight ahead").font(DS.Typography.headline).foregroundStyle(.white)
        default:
            VStack(spacing: 4) {
                Text(framingMessage).font(DS.Typography.headline).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(view == .front ? "Face the camera, arms relaxed by your sides." : "Turn side-on to the camera, arms relaxed.")
                    .font(DS.Typography.footnote).foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private var framingMessage: String {
        guard let l = camera.landmarks else { return "Step back until your whole upper body is in view" }
        switch view {
        case .front:
            if l.leftShoulder == nil || l.rightShoulder == nil { return "Make sure both shoulders are visible" }
            if l.leftHip == nil || l.rightHip == nil { return "Step back so your hips are in view too" }
        case .side:
            if (l.leftEar == nil || l.leftShoulder == nil) && (l.rightEar == nil || l.rightShoulder == nil) { return "Turn side-on so one ear and shoulder are visible" }
        }
        return "Perfect. Hold that position"
    }

    private func isFramed(_ l: BodyLandmarks) -> Bool {
        switch view {
        case .front: return l.leftShoulder != nil && l.rightShoulder != nil && l.leftHip != nil && l.rightHip != nil
        case .side: return (l.leftEar != nil && l.leftShoulder != nil) || (l.rightEar != nil && l.rightShoulder != nil)
        }
    }

    private func handle(_ landmarks: BodyLandmarks?) {
        switch stage {
        case .framing:
            if let landmarks, isFramed(landmarks) { steadyFrames += 1 } else { steadyFrames = 0 }
            if steadyFrames >= 12 { runCountdown() }
        case .reading:
            if let landmarks { samples.append(landmarks) }
        default:
            break
        }
    }

    private func runCountdown() {
        steadyFrames = 0
        Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                stage = .countdown(n)
                tick += 1
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            samples = []
            stage = .reading
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            finishReading()
        }
    }

    private func finishReading() {
        camera.stop()
        let averaged = PostureScoring.average(samples)
        let scored = view == .front ? PostureScoring.front(averaged) : PostureScoring.side(averaged)
        guard let scored else {
            stage = .framing
            camera.start()
            return
        }
        result = scored
        repository.savePostureCheck(scored.record(at: Date()), for: profile.id)
        tick += 1
        stage = .result
    }

    // MARK: Result

    private var resultView: some View {
        ScrollView {
            if let result {
                VStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        AmbientGlow().frame(width: 280, height: 280)
                        ProgressRing(progress: Double(result.score) / 100, lineWidth: 14) {
                            VStack(spacing: 0) {
                                Text("\(result.score)").font(DS.Typography.heroNumber).foregroundStyle(DS.Colors.textPrimary)
                                Text("of 100").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                        .frame(width: 200, height: 200)
                    }
                    VStack(spacing: DS.Spacing.xs) {
                        Text(result.label).font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
                        if let previous = previousScore {
                            let delta = result.score - previous
                            Badge(delta == 0 ? "Same as last time" : (delta > 0 ? "Up \(delta) since last check" : "Down \(-delta) since last check"),
                                  tone: delta >= 0 ? .accent : .neutral)
                        }
                    }
                    AppCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Text("What the camera saw").font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                            ForEach(result.findings, id: \.self) { finding in
                                Label(finding, systemImage: "scope").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeader("Routines that help")
                        ForEach(RoutineLibrary.suggestions(for: result.record(at: Date())).prefix(2)) { routine in
                            RoutineRow(routine: routine, isLocked: false) { playingRoutine = routine }
                        }
                    }
                    Text("A self-check for everyday habits, not a medical assessment. Clothing, lighting and how you stand all affect the reading.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary).multilineTextAlignment(.center)
                    AppButton("Done") { dismiss() }
                }
                .padding(DS.Spacing.page)
            }
        }
    }

    private var previousScore: Int? {
        let checks = (repository.profiles.first { $0.id == profile.id }?.wellness.postureChecks ?? []).filter { $0.view == view }.sorted { $0.date < $1.date }
        return checks.count >= 2 ? checks[checks.count - 2].score : nil
    }
}
#endif
