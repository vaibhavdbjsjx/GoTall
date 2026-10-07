import Foundation

/// A readable summary of a profile. Used by the onboarding summary (built from the provisional
/// profile, so it shows exactly what will be stored) and by the Profile tab.
public struct ProfileSummary: Equatable, Sendable {
    public struct Row: Equatable, Sendable, Identifiable {
        public var label: String
        public var value: String
        public var id: String { label }
    }

    public struct Section: Equatable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var symbol: String
        public var rows: [Row]
        /// Onboarding step that edits this section.
        public var editStep: OnboardingStep?
    }

    public var sections: [Section]

    public init(profile: GrowthProfile, now: Date, calendar: Calendar, locale: Locale = .current) {
        let unit = profile.unitPreference
        var sections: [Section] = []
        let notProvided = "Not provided"

        let age = profile.age(on: now, calendar: calendar)
        var basics: [Row] = []
        if let nickname = profile.nickname { basics.append(Row(label: "Name", value: nickname)) }
        basics.append(Row(label: "Age", value: age.map { "\($0.years) years, \($0.months) months" } ?? "—"))
        basics.append(Row(label: "Born", value: DisplayFormat.day(profile.birthDate, calendar: calendar, locale: locale)))
        sections.append(Section(id: "basics", title: "Basics", symbol: "person.text.rectangle", rows: basics, editStep: .birthDate))
        sections.append(Section(id: "chart", title: "Growth chart", symbol: "chart.line.uptrend.xyaxis",
                                rows: [Row(label: "Chart", value: profile.chartSex.title)], editStep: .chartSex))

        if let latest = profile.latestMeasurement {
            var heightRows = [
                Row(label: "Current height", value: HeightFormatter.string(centimeters: latest.heightCm, unit: unit)),
                Row(label: "Measured", value: latest.method.title)
            ]
            let earlier = profile.measurements.count - 1
            heightRows.append(Row(label: "Earlier measurements", value: earlier == 0 ? "None yet" : "\(earlier)"))
            sections.append(Section(id: "height", title: "Height", symbol: "ruler", rows: heightRows, editStep: .currentHeight))
        }

        let band = age?.band
        if band?.isStillGrowing == true {
            func parentValue(_ answer: ParentHeightAnswer?) -> String {
                switch answer {
                case .known(let cm, let source)?: return HeightFormatter.string(centimeters: cm, unit: unit) + (source == .estimated ? " (estimate)" : "")
                case .unknown?: return "Don't know"
                case nil: return notProvided
                }
            }
            sections.append(Section(id: "family", title: "Family height", symbol: "person.2", rows: [
                Row(label: "Biological mother", value: parentValue(profile.parentHeights.mother)),
                Row(label: "Biological father", value: parentValue(profile.parentHeights.father))
            ], editStep: .parentHeights))
        }

        if band != .adult {
            sections.append(Section(id: "change", title: "Recent growth", symbol: "arrow.up.right", rows: [
                Row(label: "Noticed", value: profile.recentGrowthChange?.title ?? notProvided)
            ], editStep: .growthChange))
        }

        let sleepRows: [Row] = [
            Row(label: "Asleep by", value: profile.sleep.bedtime.map { DisplayFormat.time($0, calendar: calendar, locale: locale) } ?? notProvided),
            Row(label: "Wakes at", value: profile.sleep.wakeTime.map { DisplayFormat.time($0, calendar: calendar, locale: locale) } ?? notProvided),
            Row(label: "Typical sleep", value: profile.sleep.typicalDurationMinutes.map { DisplayFormat.duration(minutes: $0) } ?? notProvided),
            Row(label: "Weekends", value: profile.sleep.consistency?.title ?? notProvided)
        ]
        sections.append(Section(id: "sleep", title: "Sleep", symbol: "moon", rows: sleepRows, editStep: .sleep))

        sections.append(Section(id: "activity", title: "Activity", symbol: "figure.run", rows: [
            Row(label: "Typical week", value: profile.activity.level?.title ?? notProvided),
            Row(label: "Sessions per week", value: profile.activity.frequency?.title ?? notProvided),
            Row(label: "Enjoys", value: profile.activity.preferred.isEmpty ? notProvided : profile.activity.preferred.map(\.title).joined(separator: ", "))
        ], editStep: .activity))

        sections.append(Section(id: "nutrition", title: "Eating", symbol: "fork.knife", rows: [
            Row(label: "Meals", value: profile.nutrition.mealRegularity?.title ?? notProvided),
            Row(label: "Pattern", value: profile.nutrition.pattern?.title ?? notProvided),
            Row(label: "Drinks", value: profile.nutrition.hydration?.title ?? notProvided)
        ], editStep: .nutrition))

        sections.append(Section(id: "goals", title: "Goals", symbol: "target", rows: [
            Row(label: "Focus", value: profile.goals.isEmpty ? notProvided : profile.goals.map(\.title).joined(separator: ", "))
        ], editStep: .goals))

        self.sections = sections
    }
}
