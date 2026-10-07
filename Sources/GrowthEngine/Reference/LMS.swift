import Foundation

/// Box-Cox power (L), median (M) and generalised coefficient of variation (S) for one age and sex.
/// Cole TJ (1990), "The LMS method for constructing normalized growth standards", Eur J Clin Nutr 44:45–60.
public struct LMS: Equatable, Sendable {
    public var l: Double
    public var m: Double
    public var s: Double

    public init(l: Double, m: Double, s: Double) {
        self.l = l
        self.m = m
        self.s = s
    }

    /// z = ((X/M)^L − 1) / (L·S), or ln(X/M)/S when L = 0.
    public func zScore(for value: Double) -> Double {
        if abs(l) < 1e-12 { return log(value / m) / s }
        return (pow(value / m, l) - 1) / (l * s)
    }

    /// X = M·(1 + L·S·z)^(1/L), or M·exp(S·z) when L = 0. `nil` if the expression is undefined.
    public func value(atZ z: Double) -> Double? {
        if abs(l) < 1e-12 { return m * exp(s * z) }
        let base = 1 + l * s * z
        guard base > 0 else { return nil }
        return m * pow(base, 1 / l)
    }

    /// Linear interpolation of each parameter.
    static func interpolate(_ a: LMS, _ b: LMS, fraction t: Double) -> LMS {
        LMS(l: a.l + (b.l - a.l) * t, m: a.m + (b.m - a.m) * t, s: a.s + (b.s - a.s) * t)
    }
}

public enum StandardNormal {
    /// Φ(z), the standard normal cumulative distribution function.
    public static func cdf(_ z: Double) -> Double {
        0.5 * erfc(-z / 2.0.squareRoot())
    }
}
