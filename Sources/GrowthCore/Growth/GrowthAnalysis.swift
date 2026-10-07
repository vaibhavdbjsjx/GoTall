import Foundation
import GrowthEngine

/// Maps app models to engine inputs. The only place where profile data meets the science.
extension GrowthChartSex {
    public var referenceSex: ReferenceSex { self == .female ? .female : .male }
}

extension MeasurementMethod {
    public var quality: MeasurementQuality {
        switch self {
        case .professional: return .professional
        case .home: return .home
        case .estimate: return .estimate
        }
    }
}

public enum FamilyHeightStatus: Sendable, Equatable {
    case available(FamilyHeightRange)
    /// Still growing but one or both parent heights are missing or unknown.
    case missingParentHeights
    /// Not shown for adults or near-adults (parent heights aren't collected after 17).
    case notApplicable
}

public struct NextMeasurement: Sendable, Equatable {
    public var suggestedDate: Date
    public var isDue: Bool
}

/// Everything the Growth and Home screens need, computed once per profile and date.
/// Lifestyle data (sleep, activity, eating), goals and intent are not inputs to any number in here.
public struct GrowthAnalysis: Sendable {
    public let profileID: UUID
    public let unit: HeightUnit
    public let referenceID: String
    public let referenceName: String
    public let sex: ReferenceSex
    public let age: Age?
    public let series: GrowthSeries
    public let velocity: VelocityAvailability
    public let family: FamilyHeightStatus
    public let adultHeight: AdultHeightOutcome
    public let signposts: [GrowthSignpost]
    public let nextMeasurement: NextMeasurement?
    public let insights: [GrowthInsight]

    public var latest: SeriesPoint? { series.latest }
    public var currentPercentile: PercentileResult? { series.latest?.percentile }
    public var latestIsEstimate: Bool { series.latest?.quality == .estimate }
}

public struct GrowthAnalyzer: Sendable {
    public var now: Date
    public var calendar: Calendar
    public var reference: GrowthReference

    public init(now: Date, calendar: Calendar, reference: GrowthReference = ReferenceRegistry.cdc2000) {
        self.now = now
        self.calendar = calendar
        self.reference = reference
    }

    /// Product convention (not a clinical rule): measure every 3 months while growing (2–17),
    /// every 6 months at 18–20, and no prompt for adults.
    public static func recommendedIntervalMonths(for band: AgeBand) -> Int? {
        switch band {
        case .child, .teen: return 3
        case .youngAdult: return 6
        case .infant, .adult: return nil
        }
    }

    public func analyze(_ profile: GrowthProfile) -> GrowthAnalysis {
        let sex = profile.chartSex.referenceSex
        let points = profile.measurements.map { GrowthPoint(date: $0.date, heightCm: $0.heightCm, quality: $0.method.quality) }
        let series = GrowthSeries(measurements: points, birthDate: profile.birthDate, sex: sex, reference: reference, calendar: calendar)
        let velocity = GrowthVelocityCalculator.velocity(for: series, calendar: calendar)
        let age = profile.age(on: now, calendar: calendar)

        let family: FamilyHeightStatus
        if age?.band.isStillGrowing == true {
            let usesEstimate = [profile.parentHeights.mother, profile.parentHeights.father].contains { answer in
                if case .known(_, .estimated)? = answer { return true }
                return false
            }
            if let range = FamilyHeightCalculator.range(motherCm: profile.parentHeights.mother?.heightCm,
                                                        fatherCm: profile.parentHeights.father?.heightCm,
                                                        sex: sex, usesEstimate: usesEstimate, reference: reference) {
                family = .available(range)
            } else {
                family = .missingParentHeights
            }
        } else {
            family = .notApplicable
        }

        let adultHeight = AdultHeightScenarioEngine.outcome(series: series, birthDate: profile.birthDate, now: now, sex: sex,
                                                            reference: reference, velocity: velocity, calendar: calendar)
        let signposts = SignpostEngine.signposts(for: series, calendar: calendar)

        var next: NextMeasurement?
        if let band = age?.band, let months = Self.recommendedIntervalMonths(for: band), let latest = series.latest,
           let date = calendar.date(byAdding: .month, value: months, to: latest.date) {
            next = NextMeasurement(suggestedDate: date, isDue: date <= calendar.startOfDay(for: now))
        }

        let partial = GrowthAnalysis(profileID: profile.id, unit: profile.unitPreference, referenceID: reference.id,
                                     referenceName: reference.displayName, sex: sex, age: age, series: series,
                                     velocity: velocity, family: family, adultHeight: adultHeight, signposts: signposts,
                                     nextMeasurement: next, insights: [])
        let insights = GrowthInsightEngine(now: now, calendar: calendar).insights(for: profile, analysis: partial)
        return GrowthAnalysis(profileID: profile.id, unit: profile.unitPreference, referenceID: reference.id,
                              referenceName: reference.displayName, sex: sex, age: age, series: series,
                              velocity: velocity, family: family, adultHeight: adultHeight, signposts: signposts,
                              nextMeasurement: next, insights: insights)
    }
}
