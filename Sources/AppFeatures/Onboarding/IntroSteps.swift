#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct WelcomeStepView: View {
    @Bindable var controller: OnboardingController

    var body: some View {
        let copy = controller.copy
        OnboardingContainer(progress: nil, title: nil, canGoBack: false, onBack: {}) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    BrandMark(size: 64)
                        .appearEffect()
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(BrandConfig.current.displayName.uppercased())
                            .font(DS.Typography.eyebrow)
                            .tracking(1.2)
                            .foregroundStyle(DS.Colors.accent)
                        Text(copy.welcomeTitle)
                            .font(DS.Typography.display)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(copy.welcomeSubtitle)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .appearEffect(delay: 0.05)
                }
                .padding(.top, DS.Spacing.xl)

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(Array(copy.welcomePoints.enumerated()), id: \.offset) { index, point in
                        FeatureRow(symbol: point.symbol, title: point.title, detail: point.detail)
                            .appearEffect(delay: 0.08 + Double(index) * 0.03)
                    }
                }
            }
        } footer: {
            AppButton(copy.welcomeAction) { controller.goNext() }
            if controller.isResumed {
                Text("Picking up where you left off.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }
}

struct PrivacyStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(
            controller: controller,
            title: copy.privacyTitle,
            primaryTitle: copy.privacyAction,
            primaryEnabled: true,
            onCancel: onCancel,
            primaryAction: {
                controller.update { $0.privacyAcknowledged = true }
                controller.goNext()
            }
        ) {
            PrivacyNotice(items: copy.privacyPoints.map { ($0.symbol, $0.title, $0.detail) })
            InfoBanner(copy.medicalNote, title: "Not medical advice")
            if let url = BrandConfig.current.privacyPolicyURL {
                Link("Read the full privacy policy", destination: url)
                    .font(DS.Typography.subheadline.weight(.semibold))
            } else {
                Text("The full privacy policy will be linked here before release.")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }
}

struct SubjectStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.subjectTitle, onCancel: onCancel) {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(ProfileSubject.allCases, id: \.self) { subject in
                    SelectionCard(title: subject.title, detail: subject.detail, systemImage: subject.symbol,
                                  isSelected: controller.draft.subject == subject) {
                        controller.update { $0.subject = subject }
                    }
                }
            }
            Text(copy.subjectFooter)
                .font(DS.Typography.footnote)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }
}

struct NicknameStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?
    @FocusState private var focused: Bool

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.nicknameTitle, subtitle: copy.nicknameSubtitle, onCancel: onCancel) {
            TextField("First name or nickname", text: Binding(
                get: { controller.draft.nickname ?? "" },
                set: { value in controller.update { $0.nickname = String(value.prefix(30)) } }
            ))
            .textContentType(.nickname)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.continue)
            .onSubmit { controller.goNext() }
            .focused($focused)
            .font(DS.Typography.title)
            .padding(DS.Spacing.md)
            .frame(minHeight: 56)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).strokeBorder(DS.Colors.separator))
            .onAppear { focused = true }
        }
    }
}

struct BirthDateStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?

    private var calendar: Calendar { controller.calendar }
    private var earliest: Date { calendar.date(byAdding: .year, value: -BirthDateValidation.maximumYears, to: controller.today) ?? controller.today }
    private var suggested: Date {
        let years = controller.draft.subject == .child ? -8 : -15
        return calendar.date(byAdding: .year, value: years, to: controller.today) ?? controller.today
    }

    var body: some View {
        let copy = controller.copy
        let validation = controller.birthDateValidation
        StepScaffold(controller: controller, title: copy.birthDateTitle, subtitle: copy.birthDateSubtitle, onCancel: onCancel) {
            AppCard(padding: DS.Spacing.xs) {
                DatePicker("Date of birth", selection: Binding(
                    get: { controller.draft.birthDate ?? suggested },
                    set: { date in controller.update { $0.birthDate = calendar.startOfDay(for: date) } }
                ), in: earliest...controller.today, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            if controller.draft.birthDate == nil {
                AppButton("Use this date", kind: .secondary) {
                    controller.update { $0.birthDate = calendar.startOfDay(for: suggested) }
                }
            }

            if let message = copy.birthDateMessage(validation) {
                switch validation {
                case .valid:
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.accent)
                        .contentTransition(.numericText())
                        .accessibilityLabel(message)
                case .needsGuardian:
                    InfoBanner(message, title: "Ask a parent or guardian", tone: .info)
                    AppButton(copy.guardianHandoffAction, systemImage: "figure.and.child.holdinghands", kind: .secondary) {
                        controller.switchToGuardianSetup()
                    }
                default:
                    InfoBanner(message, tone: .caution)
                }
            }
        }
    }
}

struct ChartSexStepView: View {
    @Bindable var controller: OnboardingController
    let onCancel: (() -> Void)?
    @State private var showsHelp = false

    var body: some View {
        let copy = controller.copy
        StepScaffold(controller: controller, title: copy.chartSexTitle, subtitle: copy.chartSexSubtitle, onCancel: onCancel) {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(GrowthChartSex.allCases, id: \.self) { sex in
                    SelectionCard(title: sex.title, systemImage: sex.symbol, isSelected: controller.draft.chartSex == sex) {
                        controller.update { $0.chartSex = sex }
                    }
                }
            }
            DisclosureGroup(isExpanded: $showsHelp) {
                Text(copy.chartSexHelp)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, DS.Spacing.xs)
            } label: {
                Text(copy.chartSexHelpTitle)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Colors.accent)
            }
            .tint(DS.Colors.accent)
        }
    }
}
#endif
