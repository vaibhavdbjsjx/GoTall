#if os(iOS)
import SwiftUI
import GrowthCore
import GrowthEngine
import DesignSystem

/// The top of the Plan tab: level and streak, today's routine, the tools grid and the routine library.
/// Owns the sheets for every tool so the rest of the tab (habits) stays unchanged.
struct PlanHubSections: View {
    let repository: AppRepository
    let profile: GrowthProfile
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(AppNavigator.self) private var navigator

    @State private var playing: Routine?
    @State private var showsPosture = false
    @State private var showsBedtime = false
    @State private var showsFood = false
    @State private var showsPuberty = false
    @State private var showsOutgrow = false
    @State private var showsDoctorKit = false
    @State private var showsReport = false

    var body: some View {
        let now = Date()
        let analysis = GrowthAnalyzer(now: now, calendar: .current).analyze(profile)
        let progression = Progression(profile: profile, today: now, calendar: .current)
        let isPro = entitlements.isPremium
        let todayRoutine = TodayPlan.routineOfTheDay(profile: profile, isPremium: isPro, today: now, calendar: .current)
        let doneToday = profile.wellness.routineSessions.contains { $0.completed && $0.routineID == todayRoutine.id && Calendar.current.isDateInToday($0.date) }
        let age = profile.age(on: now, calendar: .current)?.years ?? 30
        let forecast = OutgrowForecast.make(profile: profile, analysis: analysis, now: now, calendar: .current)

        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            // LEVEL
            HStack(spacing: DS.Spacing.md) {
                LevelChip(level: progression.level.number, name: progression.level.name, progress: progression.progressToNext)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(progression.activeStreak)").font(DS.Typography.metricSmall).foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("day streak").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(progression.totalPoints)").font(DS.Typography.metricSmall).foregroundStyle(DS.Colors.textPrimary)
                        .contentTransition(.numericText())
                    Text("points").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            .appearEffect()

            // TODAY'S ROUTINE
            Button { playing = todayRoutine } label: {
                ZStack(alignment: .topTrailing) {
                    AmbientGlow().frame(width: 220, height: 220).offset(x: 60, y: -60)
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(doneToday ? "DONE TODAY" : "TODAY'S ROUTINE").font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.accent)
                        Text(todayRoutine.title).font(DS.Typography.display).foregroundStyle(DS.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Text(todayRoutine.subtitle).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                        HStack {
                            Label("\(todayRoutine.minutes) min", systemImage: "clock").font(DS.Typography.footnote.weight(.semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: doneToday ? "arrow.counterclockwise" : "play.fill")
                                Text(doneToday ? "Again" : "Start")
                            }
                            .font(DS.Typography.headline)
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.md)
                            .frame(minHeight: 44)
                            .background(DS.Colors.accent, in: Capsule())
                        }
                        .padding(.top, DS.Spacing.xs)
                    }
                    .padding(DS.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .clipped()
                .heroSurface()
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("plan.todayRoutine")
            .appearEffect(delay: 0.04)

            // TOOLS
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                SectionHeader("Tools")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                    let lastPosture = profile.wellness.latestPostureCheck
                    ToolTile(symbol: "figure.stand", title: "Posture check",
                             status: lastPosture.map { "Last score \($0.score)" } ?? "30 seconds, first one free",
                             isLocked: lastPosture != nil && !isPro) {
                        if lastPosture == nil || isPro { showsPosture = true } else { navigator.showPaywall(.posture) }
                    }
                    ToolTile(symbol: "moon.stars", title: "Bedtime planner",
                             status: bedtimeStatus(age: age)) { showsBedtime = true }
                    ToolTile(symbol: "fork.knife", title: "Food variety",
                             status: "\(MealLog.groups(on: now, in: profile, calendar: .current).count) groups today") { showsFood = true }
                    if forecast != nil {
                        ToolTile(symbol: "tshirt", title: "Outgrow forecast",
                                 status: forecast.flatMap { f in f.nextSizeChange.map { "Size \($0.clothingSize) in ~\($0.months) mo" } } ?? "Sizes for the next year",
                                 isLocked: !isPro) {
                            if isPro { showsOutgrow = true } else { navigator.showPaywall(.outgrow) }
                        }
                    }
                    if age < 18 {
                        ToolTile(symbol: "person.crop.circle.badge.questionmark", title: "Puberty check",
                                 status: profile.wellness.puberty.map { PubertyCheck.title($0.stage) } ?? "5 quick questions") { showsPuberty = true }
                    }
                    ToolTile(symbol: "stethoscope", title: "Doctor visit kit", status: "Questions and report", isLocked: !isPro) {
                        if isPro { showsDoctorKit = true } else { navigator.showPaywall(.report) }
                    }
                }
            }
            .appearEffect(delay: 0.08)

            // ROUTINES
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                SectionHeader("Routines")
                ForEach(RoutineLibrary.all) { routine in
                    let locked = !routine.isFree && !isPro
                    RoutineRow(routine: routine, isLocked: locked) {
                        if locked { navigator.showPaywall(.routines) } else { playing = routine }
                    }
                }
                Text("\(RoutineLibrary.moveCount) guided moves for posture, mobility and core strength. They help you stand tall and feel good; they don't change bone length.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fullScreenCover(item: $playing) { routine in
            RoutinePlayerView(routine: routine, repository: repository, profileID: profile.id)
        }
        .fullScreenCover(isPresented: $showsPosture) {
            PostureCheckView(repository: repository, profile: profile)
        }
        .sheet(isPresented: $showsBedtime) { BedtimePlannerView(repository: repository, profile: profile) }
        .sheet(isPresented: $showsFood) { FoodVarietyView(repository: repository, profileID: profile.id) }
        .sheet(isPresented: $showsPuberty) { PubertyCheckView(repository: repository, profile: profile) }
        .sheet(isPresented: $showsOutgrow) {
            if let forecast { OutgrowForecastView(forecast: forecast, profile: profile) }
        }
        .sheet(isPresented: $showsDoctorKit) {
            DoctorVisitKitView(kit: DoctorVisitKit.make(profile: profile, analysis: analysis, now: now, calendar: .current),
                               title: profile.subject == .child ? (profile.nickname ?? "Child") : "Your",
                               onOpenReport: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showsReport = true } })
        }
        .sheet(isPresented: $showsReport) {
            NavigationStack {
                ReportPreviewView(repository: repository)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsReport = false } } }
            }
        }
    }

    private func bedtimeStatus(age: Int) -> String {
        guard let settings = profile.wellness.bedtime else { return "Find your ideal bedtime" }
        let plan = BedtimePlanner.plan(settings: settings, ageYears: age)
        return "Bed by \(BedtimePlanner.timeText(plan.bedtimeMinutes))"
    }
}
#endif
