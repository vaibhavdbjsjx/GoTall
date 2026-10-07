#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct SleepStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.sleepTitle, subtitle: copy.sleepSubtitle, onCancel: onCancel) {
            SleepBaselineEditor(sleep: controller.binding(\.sleep), defaults: SleepDefaults.forBand(controller.ageBand),
                                bedtimeLabel: copy.bedtimeLabel, wakeLabel: copy.wakeLabel, consistencyLabel: copy.sleepConsistencyLabel)
        }
    }
}

struct ActivityStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.activityTitle, subtitle: copy.activitySubtitle, onCancel: onCancel) {
            ActivityBaselineEditor(activity: controller.binding(\.activity), frequencyLabel: copy.activityFrequencyLabel, preferredLabel: copy.activityPreferredLabel)
        }
    }
}

struct NutritionStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.nutritionTitle, subtitle: copy.nutritionSubtitle, onCancel: onCancel) {
            NutritionBaselineEditor(nutrition: controller.binding(\.nutrition), copy: copy)
        }
    }
}
#endif
