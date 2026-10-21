#if os(iOS)
import SwiftUI
import Combine
import GrowthCore
import DesignSystem

/// Full-screen guided routine: one move at a time with a countdown ring, a short rest between moves,
/// a "switch sides" cue halfway through one-sided moves, and haptics at each change. Pausable at any time.
struct RoutinePlayerView: View {
    let routine: Routine
    let repository: AppRepository
    let profileID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase: Equatable {
        case ready
        case move(Int)
        case rest(next: Int)
        case finished
    }

    @State private var phase: Phase = .ready
    @State private var remaining: Double = 0
    @State private var isPaused = false
    @State private var activeSeconds: Double = 0
    @State private var switchedSides = false
    @State private var cueTick = 0
    @State private var startedAt = Date()
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            PageBackdrop().ignoresSafeArea()
            VStack(spacing: DS.Spacing.lg) {
                topBar
                Spacer(minLength: 0)
                switch phase {
                case .ready: readyView
                case .move(let index): moveView(routine.moves[index], index: index)
                case .rest(let next): restView(next: routine.moves[next])
                case .finished: finishedView
                }
                Spacer(minLength: 0)
                controls
            }
            .padding(DS.Spacing.page)
        }
        .animation(Motion.resolved(Motion.page, reduceMotion: reduceMotion), value: phase)
        .onReceive(ticker) { _ in tick() }
        .sensoryFeedback(.impact(weight: .medium), trigger: cueTick)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                if case .move = phase { save(completed: false) } else if case .rest = phase { save(completed: false) }
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.surfaceSecondary, in: Circle())
            }
            .accessibilityLabel("Close")
            Spacer()
            if case .move(let i) = phase {
                StepDots(count: routine.moves.count, current: i)
            } else if case .rest(let i) = phase {
                StepDots(count: routine.moves.count, current: i)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var readyView: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                AmbientGlow().frame(width: 260, height: 260)
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(DS.Colors.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
            }
            Text(routine.focus.title.uppercased()).font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
            Text(routine.title).font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary).multilineTextAlignment(.center)
            Text("\(routine.moves.count) moves · \(routine.minutes) min").font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
            Text(routine.subtitle).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary).multilineTextAlignment(.center)
        }
        .transition(.opacity)
    }

    private func moveView(_ move: RoutineMove, index: Int) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressRing(progress: 1 - remaining / Double(move.seconds), lineWidth: 12) {
                VStack(spacing: 2) {
                    Text("\(Int(remaining.rounded(.up)))")
                        .font(DS.Typography.heroNumber)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                    Text("seconds").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .frame(width: 220, height: 220)
            VStack(spacing: DS.Spacing.xs) {
                Text(move.name).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary).multilineTextAlignment(.center)
                if move.perSide {
                    Badge(switchedSides ? "Second side" : "First side", tone: .accent)
                }
                Text(move.instruction).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Label(move.cue, systemImage: "lightbulb")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .id("move-\(index)")
        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }

    private func restView(next: RoutineMove) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Breathe").font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
            Text("\(Int(remaining.rounded(.up)))").font(DS.Typography.heroNumber).foregroundStyle(DS.Colors.accent)
                .contentTransition(.numericText(countsDown: true))
            Text("Next: \(next.name)").font(DS.Typography.headline).foregroundStyle(DS.Colors.textSecondary)
        }
        .transition(.opacity)
    }

    private var finishedView: some View {
        VStack(spacing: DS.Spacing.md) {
            SuccessSeal()
            Text("Routine complete").font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
            Text("+\(Progression.Points.routine) points · \(max(1, Int((activeSeconds / 60).rounded()))) min of movement")
                .font(DS.Typography.headline).foregroundStyle(DS.Colors.accent)
            Text("Small sessions most days do more than one long one a week.")
                .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary).multilineTextAlignment(.center)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .ready:
            AppButton("Start", systemImage: "play.fill") { start() }
        case .move, .rest:
            HStack(spacing: DS.Spacing.sm) {
                AppButton(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill", kind: .secondary) { isPaused.toggle() }
                AppButton("Skip", systemImage: "forward.fill", kind: .tertiary, fullWidth: false) { advance() }
            }
        case .finished:
            AppButton("Done") { dismiss() }
        }
    }

    // MARK: Timing

    private func start() {
        startedAt = Date()
        begin(move: 0)
    }

    private func begin(move index: Int) {
        switchedSides = false
        remaining = Double(routine.moves[index].seconds)
        phase = .move(index)
        cueTick += 1
    }

    private func tick() {
        guard !isPaused else { return }
        switch phase {
        case .move(let index):
            remaining -= 0.1
            activeSeconds += 0.1
            let move = routine.moves[index]
            if move.perSide, !switchedSides, remaining <= Double(move.seconds) / 2 {
                switchedSides = true
                cueTick += 1
            }
            if remaining <= 0 { advance() }
        case .rest(let next):
            remaining -= 0.1
            if remaining <= 0 { begin(move: next) }
        default:
            break
        }
    }

    private func advance() {
        switch phase {
        case .move(let index):
            if index + 1 < routine.moves.count {
                remaining = Double(routine.restSeconds)
                phase = .rest(next: index + 1)
                cueTick += 1
            } else {
                finish()
            }
        case .rest(let next):
            begin(move: next)
        default:
            break
        }
    }

    private func finish() {
        save(completed: true)
        phase = .finished
        cueTick += 1
    }

    private func save(completed: Bool) {
        guard activeSeconds >= 20 || completed else { return }
        repository.logRoutine(RoutineSession(routineID: routine.id, date: Date(), activeSeconds: Int(activeSeconds), completed: completed), for: profileID)
    }
}

/// Small progress dots for the routine's moves.
private struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? DS.Colors.accent : DS.Colors.surfaceSecondary)
                    .frame(width: i == current ? 18 : 6, height: 6)
            }
        }
        .animation(Motion.standard, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Move \(current + 1) of \(count)")
    }
}
#endif
