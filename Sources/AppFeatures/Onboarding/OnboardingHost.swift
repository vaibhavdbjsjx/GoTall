#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Owns one `OnboardingController` for the lifetime of the flow and animates between steps.
struct OnboardingHost: View {
    let repository: AppRepository
    let mode: OnboardingMode
    let onCancel: (() -> Void)?
    let onFinish: (() -> Void)?
    /// Created once, lazily, so re-rendering the parent never builds a second controller.
    @State private var controller: OnboardingController?

    init(repository: AppRepository, mode: OnboardingMode, onCancel: (() -> Void)? = nil, onFinish: (() -> Void)? = nil) {
        self.repository = repository
        self.mode = mode
        self.onCancel = onCancel
        self.onFinish = onFinish
    }

    var body: some View {
        Group {
            if let controller {
                // No NavigationStack: it reserved hidden navigation-bar space and pushed content down
                // (seen in simulator screenshots). The keyboard Done button lives in OnboardingContainer's top bar.
                OnboardingFlowView(controller: controller, onCancel: onCancel)
                .onChange(of: controller.completedProfile) { _, profile in
                    if profile != nil { onFinish?() }
                }
            } else {
                DS.Colors.background.ignoresSafeArea()
            }
        }
        .onAppear {
            if controller == nil { controller = OnboardingController(repository: repository, mode: mode) }
        }
    }
}

struct OnboardingFlowView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            stepView(for: controller.currentStep)
                .id(controller.currentStep)
                .transition(Motion.stepTransition(forward: controller.direction == .forward, reduceMotion: reduceMotion))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Motion.resolved(Motion.page, reduceMotion: reduceMotion), value: controller.currentStep)
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome: WelcomeStepView(controller: controller)
        case .privacy: PrivacyStepView(controller: controller, onCancel: onCancel)
        case .subject: SubjectStepView(controller: controller, onCancel: onCancel)
        case .nickname: NicknameStepView(controller: controller, onCancel: onCancel)
        case .birthDate: BirthDateStepView(controller: controller, onCancel: onCancel)
        case .chartSex: ChartSexStepView(controller: controller, onCancel: onCancel)
        case .currentHeight: CurrentHeightStepView(controller: controller, onCancel: onCancel)
        case .parentHeights: ParentHeightsStepView(controller: controller, onCancel: onCancel)
        case .historyQuestion: HistoryQuestionStepView(controller: controller, onCancel: onCancel)
        case .historyEntry: HistoryEntryStepView(controller: controller, onCancel: onCancel)
        case .growthChange: GrowthChangeStepView(controller: controller, onCancel: onCancel)
        case .sleep: SleepStepView(controller: controller, onCancel: onCancel)
        case .activity: ActivityStepView(controller: controller, onCancel: onCancel)
        case .nutrition: NutritionStepView(controller: controller, onCancel: onCancel)
        case .goals: GoalsStepView(controller: controller, onCancel: onCancel)
        case .intent: IntentStepView(controller: controller, onCancel: onCancel)
        case .concernSupport: ConcernSupportStepView(controller: controller, onCancel: onCancel)
        case .buildingProfile: BuildingProfileStepView(controller: controller)
        case .summary: SummaryStepView(controller: controller, onCancel: onCancel)
        }
    }
}

// MARK: - Shared step frame

/// Wraps `OnboardingContainer` with the controller's progress, back, skip and continue behaviour.
struct StepScaffold<Content: View>: View {
    @Bindable var controller: OnboardingController
    let title: String?
    let subtitle: String?
    let primaryTitle: String
    let primaryAction: (() -> Void)?
    let primaryEnabled: Bool?
    let onCancel: (() -> Void)?
    let content: Content

    init(
        controller: OnboardingController,
        title: String?,
        subtitle: String? = nil,
        primaryTitle: String? = nil,
        primaryEnabled: Bool? = nil,
        onCancel: (() -> Void)? = nil,
        primaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.controller = controller
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle ?? (controller.draft.editingFromSummary ? "Save" : "Continue")
        self.primaryEnabled = primaryEnabled
        self.onCancel = onCancel
        self.primaryAction = primaryAction
        self.content = content()
    }

    static var chapterTitles: [String] { ["Profile", "Growth", "Lifestyle", "Goals", "Summary"] }

    private var progressModel: OnboardingProgressModel? {
        let progress = controller.progress
        guard let index = progress.chapterIndex else { return nil }
        return OnboardingProgressModel(chapters: Self.chapterTitles, currentIndex: index, fractionWithinChapter: progress.fractionWithinChapter)
    }

    private var canGoBack: Bool { controller.canGoBack || onCancel != nil }

    var body: some View {
        OnboardingContainer(
            progress: progressModel,
            title: title,
            subtitle: subtitle,
            canGoBack: canGoBack,
            onBack: {
                if controller.canGoBack { controller.goBack() } else { onCancel?() }
            },
            skipTitle: controller.currentStep.isSkippable ? "Skip" : nil,
            onSkip: controller.currentStep.isSkippable ? { controller.skip() } : nil
        ) {
            content
        } footer: {
            AppButton(primaryTitle) {
                if let primaryAction { primaryAction() } else { controller.goNext() }
            }
            .disabled(!(primaryEnabled ?? controller.canContinue))
        }
    }
}

extension OnboardingController {
    /// Two-way binding into the draft; every write is persisted.
    func binding<Value>(_ keyPath: WritableKeyPath<OnboardingDraft, Value>) -> Binding<Value> {
        Binding(
            get: { self.draft[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }
}

/// Small label above a group of options.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(DS.Typography.subheadline.weight(.semibold))
            .foregroundStyle(DS.Colors.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}
#endif
