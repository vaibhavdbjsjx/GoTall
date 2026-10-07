#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Calm daily check-ins for healthy development. Weekly consistency, forgiving rhythm, no failure states.
struct HabitsView: View {
    let repository: AppRepository
    @State private var choosingHabits = false
    @State private var editingBaselines = false

    var body: some View {
        NavigationStack {
            Group {
                if let profile = repository.activeProfile {
                    content(profile: profile)
                } else {
                    LoadingStateView()
                }
            }
            .dsPageBackground()
            .navigationTitle("Habits")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ProfileSwitcher(repository: repository) } }
            .sheet(isPresented: $choosingHabits) {
                if let profile = repository.activeProfile {
                    HabitPickerSheet(repository: repository, profile: profile)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $editingBaselines) {
                if let profile = repository.activeProfile {
                    EditProfileView(repository: repository, profile: profile, focus: .lifestyle)
                }
            }
        }
    }

    private func content(profile: GrowthProfile) -> some View {
        let engine = HabitEngine(today: Date(), calendar: .current)
        let habits = HabitEngine.activeHabits(for: profile)
        let today = engine.status(on: Date(), in: profile)
        let rhythm = engine.rhythm(in: profile)
        return ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // TODAY
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today").font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary).accessibilityAddTraits(.isHeader)
                            Text(engine.encouragement(in: profile)).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                                .contentTransition(.opacity)
                        }
                        Spacer()
                        Text("\(today.completed)/\(today.total)")
                            .font(DS.Typography.metricSmall)
                            .foregroundStyle(DS.Colors.accent)
                            .contentTransition(.numericText())
                            .accessibilityLabel("\(today.completed) of \(today.total) done today")
                    }
                    AppCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(habits.enumerated()), id: \.element) { index, kind in
                                CheckInRow(title: kind.title, subtitle: kind.prompt, symbol: kind.symbol,
                                           isDone: engine.isCompleted(kind, on: Date(), in: profile)) {
                                    withAnimation(Motion.standard) {
                                        repository.toggleHabit(kind, on: Date(), for: profile.id, today: Date(), calendar: .current)
                                    }
                                }
                                if index < habits.count - 1 { Divider().padding(.leading, 72) }
                            }
                        }
                    }
                    Button { choosingHabits = true } label: {
                        Label("Choose habits", systemImage: "slider.horizontal.3")
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .frame(minHeight: DS.minimumTapTarget)
                    }
                    .foregroundStyle(DS.Colors.accent)
                }

                // WEEK
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    SectionHeader("This week")
                    AppCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            WeekDots(days: weekDays(engine: engine, profile: profile), size: 32)
                            Divider()
                            HStack(spacing: DS.Spacing.lg) {
                                stat("\(engine.checkInDaysThisWeek(in: profile)) of 7", "days with a check-in")
                                stat(rhythm == 1 ? "1 day" : "\(rhythm) days", "current rhythm")
                            }
                            Text("Rhythm counts check-in days in a row and forgives one missed day each week.")
                                .font(DS.Typography.footnote)
                                .foregroundStyle(DS.Colors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(habits) { kind in
                            HabitWeekRow(kind: kind, count: engine.weekCount(for: kind, in: profile))
                        }
                    }
                }

                // FOUR WEEKS
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    SectionHeader("Last four weeks")
                    AppCard {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            ConsistencyGrid(fractions: engine.recentDays(28, in: profile).map(\.fraction))
                            Text("Darker squares mean more of that day's habits were done.")
                                .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                }

                // PATTERNS
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    SectionHeader("Patterns")
                    if let best = engine.mostConsistent(in: profile) {
                        InsightCardView(insight: GrowthInsight(kind: .measureConsistently, symbol: best.kind.symbol,
                                                               title: "Most consistent: \(best.kind.title.lowercased())",
                                                               body: "Done on \(best.days) of the last 14 days. Steady routines are easier to keep than big changes."))
                    } else {
                        EmptyStateView(systemImage: "sparkles", title: "Patterns appear with a little history",
                                       message: "After about a week of check-ins, you'll see which routines are going well.")
                            .dsSurface()
                    }
                    QuietNote(title: "About habits", message: "These support healthy development and wellbeing. They don't change any height estimate.", symbol: "info.circle")
                }

                // STARTING POINTS
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HabitBaselineSection(habits: DashboardBuilder(now: Date(), calendar: .current).build(for: profile).habits)
                    Button { editingBaselines = true } label: {
                        Label("Update starting points", systemImage: "pencil")
                            .font(DS.Typography.subheadline.weight(.semibold))
                            .frame(minHeight: DS.minimumTapTarget)
                    }
                    .foregroundStyle(DS.Colors.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.page)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(DS.Typography.metricSmall).foregroundStyle(DS.Colors.textPrimary).contentTransition(.numericText())
            Text(label).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func weekDays(engine: HabitEngine, profile: GrowthProfile) -> [WeekDots.Day] {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return engine.recentDays(7, in: profile).map {
            WeekDots.Day(id: $0.date, letter: formatter.string(from: $0.date), fraction: $0.fraction, isToday: $0.isToday)
        }
    }
}

private struct HabitWeekRow: View {
    let kind: HabitKind
    let count: Int

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: kind.symbol).foregroundStyle(DS.Colors.accent).frame(width: 24).accessibilityHidden(true)
            Text(kind.title).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { i in
                    Capsule().fill(i < count ? DS.Colors.accent : DS.Colors.surfaceSecondary).frame(width: 10, height: 6)
                }
            }
            Text("\(count)/7").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary).monospacedDigit().frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, DS.Spacing.md)
        .frame(minHeight: 44)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), \(count) of 7 days")
    }
}

/// Choose up to four habits. Explains why each one is there.
struct HabitPickerSheet: View {
    let repository: AppRepository
    let profile: GrowthProfile
    @Environment(\.dismiss) private var dismiss
    @State private var selection: [HabitKind]

    init(repository: AppRepository, profile: GrowthProfile) {
        self.repository = repository
        self.profile = profile
        _selection = State(initialValue: HabitEngine.activeHabits(for: profile))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Pick up to \(HabitEngine.maximumActive). Fewer is often easier to keep.")
                        .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    ForEach(HabitKind.allCases) { kind in
                        SelectionCard(title: kind.title, detail: kind.why, systemImage: kind.symbol, isSelected: selection.contains(kind)) {
                            if let i = selection.firstIndex(of: kind) {
                                if selection.count > 1 { selection.remove(at: i) }
                            } else if selection.count < HabitEngine.maximumActive {
                                selection.append(kind)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.page)
            }
            .dsPageBackground()
            .navigationTitle("Choose habits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        repository.setActiveHabits(selection, for: profile.id)
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif
