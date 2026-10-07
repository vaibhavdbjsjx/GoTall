import Foundation

/// Qualitative uncertainty. Deliberately no percentages (docs/growth-engine.md §7).
public enum UncertaintyLevel: Int, Sendable, Comparable, CaseIterable {
    case narrower = 0
    case moderate = 1
    case wider = 2

    public static func < (lhs: UncertaintyLevel, rhs: UncertaintyLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    func adjusted(by steps: Int, floor: UncertaintyLevel = .narrower) -> UncertaintyLevel {
        let value = min(max(rawValue + steps, floor.rawValue), UncertaintyLevel.wider.rawValue)
        return UncertaintyLevel(rawValue: value) ?? .wider
    }
}

/// Why the uncertainty is what it is. Each maps to plain-language copy in the app.
public enum UncertaintyDriver: String, Sendable, CaseIterable {
    /// Many years of growth remain.
    case farFromAdultAge
    /// Inside the typical puberty age window, when percentile positions can shift.
    case pubertyAgeWindow
    /// Past the typical growth spurt; little growth usually remains.
    case lateAdolescence
    /// The estimate relies on an estimated (not measured) height.
    case estimatedMeasurement
    /// The latest measurement is more than 6 months old.
    case staleMeasurement
    /// Only one measurement day, so consistency can't be checked yet.
    case singleMeasurement
    /// Percentile position moved by more than 0.5 SD over ≥ 12 months.
    case percentileShifting
    /// Three or more measurements over ≥ 12 months stayed within 0.25 SD.
    case consistentHistory
}

public struct AdultHeightScenario: Sendable, Equatable {
    public var lowCm: Double
    public var highCm: Double
    /// The percentile lines bounding the scenario channel.
    public var lowerLine: MajorPercentile
    public var upperLine: MajorPercentile
    /// z-score the scenario is based on (mean of recent measurements).
    public var basisZ: Double
    public var basisPercentile: Double
    public var basisPointCount: Int
    public var uncertainty: UncertaintyLevel
    public var drivers: [UncertaintyDriver]
    public var referenceID: String
    public var adultAgeMonths: Double
}

public enum NearAdultStatus: Sendable, Equatable {
    /// Growth speed available and under 1 cm/year.
    case growthMostlyComplete
    /// Growth speed available and at least 1 cm/year.
    case stillGrowing(cmPerYear: Double)
    /// Not enough history to tell.
    case unknown
}

public enum AdultHeightOutcome: Sendable, Equatable {
    case scenario(AdultHeightScenario)
    /// Under 2 years: outside the supported reference range.
    case unsupportedAge
    /// 2–3 years: chart and percentile only.
    case chartOnlyAge
    /// 18–20 years: near adult height; trend messaging only.
    case nearAdult(NearAdultStatus)
    /// 21+: measured height is adult height.
    case adult
    /// Current position is below the 3rd or above the 97th percentile, where a channel can't be formed
    /// and estimates are least reliable. No range is shown.
    case outsideTypicalRange(percentile: Double)
    /// No measurement inside the reference range.
    case insufficientData
}

/// Current growth-percentile scenario (docs/growth-engine.md §6). Not a prediction: it answers
/// "if growth stays in the current percentile channel, what adult height would that correspond to?"
///
/// Range = adult heights (at the reference's terminal age) of the major percentile lines that bound
/// the current position. When uncertainty is "wider", the channel is widened by one line on each side.
/// Nothing is averaged with the family-height range, and lifestyle data is not an input.
public enum AdultHeightScenarioEngine {
    public static let eligibleAgeYears = 4..<18
    public static let basisWindowDays = 365
    public static let maximumBasisPoints = 3
    public static let staleAfterDays = 183
    public static let shiftThresholdZ = 0.5
    public static let consistentThresholdZ = 0.25
    public static let nearAdultCompleteCmPerYear = 1.0

    public static func outcome(series: GrowthSeries, birthDate: Date, now: Date, sex: ReferenceSex,
                               reference: GrowthReference, velocity: VelocityAvailability, calendar: Calendar) -> AdultHeightOutcome {
        // Eligibility uses completed years so that boundaries fall exactly on birthdays.
        let ageNowYears = AgeMath.completedYears(birthDate: birthDate, on: now, calendar: calendar)
        switch ageNowYears {
        case ..<2: return .unsupportedAge
        case 2..<4: return .chartOnlyAge
        case 18..<21:
            if case .available(let result) = velocity {
                return .nearAdult(result.cmPerYear < nearAdultCompleteCmPerYear ? .growthMostlyComplete : .stillGrowing(cmPerYear: result.cmPerYear))
            }
            return .nearAdult(.unknown)
        case 21...: return .adult
        default: break
        }

        guard let latest = series.chartablePoints.last, let adultAge = reference.adultAgeMonths(for: .stature, sex: sex) else {
            return .insufficientData
        }

        // Basis: up to 3 most recent measurement days within 12 months of the latest, preferring measured over estimated.
        let window = series.chartablePoints.filter { AgeMath.days(from: $0.date, to: latest.date, calendar: calendar) <= basisWindowDays }
        let measured = window.filter { $0.quality != .estimate }
        let basisPoints = Array((measured.isEmpty ? window : measured).suffix(maximumBasisPoints))
        let zs = basisPoints.compactMap { $0.percentile?.z }
        guard !zs.isEmpty else { return .insufficientData }
        let basisZ = zs.reduce(0, +) / Double(zs.count)

        if basisZ < MajorPercentile.p3.z || basisZ > MajorPercentile.p97.z {
            return .outsideTypicalRange(percentile: StandardNormal.cdf(basisZ) * 100)
        }

        let (level, drivers) = uncertainty(series: series, basisPoints: basisPoints, latest: latest, now: now, sex: sex, calendar: calendar)

        let lines = MajorPercentile.allCases
        var lowerIndex = lines.lastIndex { $0.z <= basisZ } ?? 0
        if lowerIndex == lines.count - 1 { lowerIndex -= 1 } // exactly on the 97th line
        var upperIndex = lowerIndex + 1
        if level == .wider {
            lowerIndex = max(lowerIndex - 1, 0)
            upperIndex = min(upperIndex + 1, lines.count - 1)
        }
        guard let low = PercentileCalculator.height(atZ: lines[lowerIndex].z, ageMonths: adultAge, sex: sex, reference: reference),
              let high = PercentileCalculator.height(atZ: lines[upperIndex].z, ageMonths: adultAge, sex: sex, reference: reference) else {
            return .insufficientData
        }

        return .scenario(AdultHeightScenario(
            lowCm: low, highCm: high,
            lowerLine: lines[lowerIndex], upperLine: lines[upperIndex],
            basisZ: basisZ, basisPercentile: StandardNormal.cdf(basisZ) * 100, basisPointCount: basisPoints.count,
            uncertainty: level, drivers: drivers, referenceID: reference.id, adultAgeMonths: adultAge
        ))
    }

    /// Rule-based uncertainty (every rule documented in docs/growth-engine.md §7).
    static func uncertainty(series: GrowthSeries, basisPoints: [SeriesPoint], latest: SeriesPoint, now: Date,
                            sex: ReferenceSex, calendar: Calendar) -> (UncertaintyLevel, [UncertaintyDriver]) {
        var drivers: [UncertaintyDriver] = []
        let ageYears = latest.ageMonths / 12

        // Rule 1: base level by age at the latest measurement. Typical puberty timing is about two years
        // earlier in girls than boys, so the windows differ by sex. (Assumption to confirm with the medical reviewer.)
        let pubertyStart: Double = sex == .female ? 10 : 11
        let lateStart: Double = sex == .female ? 14 : 15
        let narrowStart: Double = sex == .female ? 16 : 17
        var level: UncertaintyLevel
        let floor: UncertaintyLevel
        if ageYears < pubertyStart {
            level = .wider; floor = .moderate; drivers.append(.farFromAdultAge)
        } else if ageYears < lateStart {
            level = .wider; floor = .moderate; drivers.append(.pubertyAgeWindow)
        } else if ageYears < narrowStart {
            level = .moderate; floor = .narrower
        } else {
            level = .narrower; floor = .narrower; drivers.append(.lateAdolescence)
        }

        // Rule 2: estimated basis → one level wider.
        let usesEstimate = basisPoints.contains { $0.quality == .estimate }
        if usesEstimate { level = level.adjusted(by: 1); drivers.append(.estimatedMeasurement) }

        // Rule 3: stale latest measurement (> 6 months) → one level wider.
        let stale = AgeMath.days(from: latest.date, to: now, calendar: calendar) > staleAfterDays
        if stale { level = level.adjusted(by: 1); drivers.append(.staleMeasurement) }

        // Rule 4: trajectory consistency over the last 24 months (only points with a percentile).
        let recent = series.chartablePoints.filter { AgeMath.days(from: $0.date, to: latest.date, calendar: calendar) <= 730 }
        if recent.count < 2 {
            drivers.append(.singleMeasurement)
        } else if let first = recent.first, let firstZ = first.percentile?.z, let lastZ = latest.percentile?.z,
                  AgeMath.days(from: first.date, to: latest.date, calendar: calendar) >= 365 {
            let zs = recent.compactMap { $0.percentile?.z }
            if abs(lastZ - firstZ) > shiftThresholdZ {
                level = level.adjusted(by: 1)
                drivers.append(.percentileShifting)
            } else if recent.filter({ $0.quality != .estimate }).count >= 3,
                      (zs.max()! - zs.min()!) <= consistentThresholdZ, !usesEstimate, !stale {
                // Rule 5: consistent history may narrow by one level, never below the age floor.
                level = level.adjusted(by: -1, floor: floor)
                drivers.append(.consistentHistory)
            }
        }
        return (level, drivers)
    }
}
