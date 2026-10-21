import Foundation

/// A 2D body landmark in image space, normalised to 0–1 with y pointing up (Vision's convention).
public struct BodyPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// The landmarks the posture check uses. Any may be missing when the camera can't see them.
public struct BodyLandmarks: Sendable, Equatable {
    public var nose: BodyPoint?
    public var leftEye: BodyPoint?
    public var rightEye: BodyPoint?
    public var leftEar: BodyPoint?
    public var rightEar: BodyPoint?
    public var leftShoulder: BodyPoint?
    public var rightShoulder: BodyPoint?
    public var leftHip: BodyPoint?
    public var rightHip: BodyPoint?

    public init(nose: BodyPoint? = nil, leftEye: BodyPoint? = nil, rightEye: BodyPoint? = nil, leftEar: BodyPoint? = nil, rightEar: BodyPoint? = nil,
                leftShoulder: BodyPoint? = nil, rightShoulder: BodyPoint? = nil, leftHip: BodyPoint? = nil, rightHip: BodyPoint? = nil) {
        self.nose = nose
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftEar = leftEar
        self.rightEar = rightEar
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.leftHip = leftHip
        self.rightHip = rightHip
    }
}

public struct PostureResult: Sendable, Equatable {
    public var view: PostureView
    public var score: Int
    public var shoulderTiltDegrees: Double?
    public var hipTiltDegrees: Double?
    public var headTiltDegrees: Double?
    public var forwardHeadDegrees: Double?
    public var findings: [String]

    public var label: String {
        switch score {
        case 85...: return "Well aligned"
        case 70..<85: return "Slight imbalance"
        default: return "Worth working on"
        }
    }

    public func record(at date: Date) -> PostureCheckRecord {
        PostureCheckRecord(date: date, view: view, score: score, shoulderTiltDegrees: shoulderTiltDegrees, hipTiltDegrees: hipTiltDegrees,
                           headTiltDegrees: headTiltDegrees, forwardHeadDegrees: forwardHeadDegrees)
    }
}

/// Turns camera landmarks into a simple, explainable alignment score.
///
/// This is a self-check for habits, not a medical assessment: phone cameras, clothing and stance all add error,
/// so the score moves in coarse steps and the copy never diagnoses. Angles are averaged over many frames by the
/// caller before scoring.
public enum PostureScoring {
    /// Tilt below this is normal day-to-day variation and costs nothing.
    public static let tiltComfortDegrees = 2.0
    /// Head-forward angle (ear in front of shoulder, from vertical) below this is typical upright posture.
    public static let forwardHeadComfortDegrees = 12.0

    /// Angle of the line between two points against horizontal, in degrees, folded into −90…90.
    /// Positive = the right-hand point (in the image) is higher.
    static func tilt(_ a: BodyPoint, _ b: BodyPoint) -> Double {
        let (left, right) = a.x <= b.x ? (a, b) : (b, a)
        let angle = atan2(right.y - left.y, right.x - left.x) * 180 / .pi
        return angle
    }

    public static func front(_ points: BodyLandmarks) -> PostureResult? {
        guard let ls = points.leftShoulder, let rs = points.rightShoulder else { return nil }
        let shoulder = tilt(ls, rs)
        let hip: Double? = {
            guard let lh = points.leftHip, let rh = points.rightHip else { return nil }
            return tilt(lh, rh)
        }()
        let head: Double? = {
            if let le = points.leftEye, let re = points.rightEye { return tilt(le, re) }
            if let le = points.leftEar, let re = points.rightEar { return tilt(le, re) }
            return nil
        }()

        var penalty = 0.0
        var findings: [String] = []
        let shoulderExcess = max(0, abs(shoulder) - tiltComfortDegrees)
        penalty += min(30, shoulderExcess * 5)
        if shoulderExcess > 0 { findings.append(String(format: "One shoulder sits higher by about %.0f°.", abs(shoulder))) }
        if let hip {
            let excess = max(0, abs(hip) - tiltComfortDegrees)
            penalty += min(25, excess * 4)
            if excess > 0 { findings.append(String(format: "Hips are tilted by about %.0f°.", abs(hip))) }
        }
        if let head {
            let excess = max(0, abs(head) - tiltComfortDegrees - 1)
            penalty += min(20, excess * 2.5)
            if excess > 0 { findings.append(String(format: "Your head leans to one side by about %.0f°.", abs(head))) }
        }
        if let nose = points.nose {
            let mid = (ls.x + rs.x) / 2
            let width = abs(rs.x - ls.x)
            if width > 0.01 {
                let offset = abs(nose.x - mid) / width
                let excess = max(0, offset - 0.08)
                penalty += min(15, excess * 100)
                if excess > 0 { findings.append("Your head sits off-centre over your shoulders.") }
            }
        }
        if findings.isEmpty { findings.append("Shoulders, hips and head are level. Nice and balanced.") }
        let score = Int(max(0, min(100, 100 - penalty)).rounded())
        return PostureResult(view: .front, score: score, shoulderTiltDegrees: shoulder, hipTiltDegrees: hip, headTiltDegrees: head,
                             forwardHeadDegrees: nil, findings: findings)
    }

    /// Side view: the angle between vertical and the line from shoulder to ear on the side facing the camera.
    public static func side(_ points: BodyLandmarks) -> PostureResult? {
        let pairs: [(BodyPoint?, BodyPoint?)] = [(points.leftEar, points.leftShoulder), (points.rightEar, points.rightShoulder)]
        guard let (ear, shoulder) = pairs.compactMap({ pair -> (BodyPoint, BodyPoint)? in
            guard let e = pair.0, let s = pair.1 else { return nil }
            return (e, s)
        }).first else { return nil }
        let dx = abs(ear.x - shoulder.x)
        let dy = ear.y - shoulder.y
        guard dy > 0.01 else { return nil }
        let forward = atan2(dx, dy) * 180 / .pi
        let excess = max(0, forward - forwardHeadComfortDegrees)
        let score = Int(max(0, min(100, 100 - min(60, excess * 3))).rounded())
        let finding = excess > 0
            ? String(format: "Your head sits about %.0f° in front of your shoulders. Chin tucks and the tech-neck routine help.", forward)
            : "Your ear lines up well over your shoulder."
        return PostureResult(view: .side, score: score, shoulderTiltDegrees: nil, hipTiltDegrees: nil, headTiltDegrees: nil,
                             forwardHeadDegrees: forward, findings: [finding])
    }

    /// Averages landmark samples (one per camera frame) point by point, ignoring frames where a point is missing.
    public static func average(_ samples: [BodyLandmarks]) -> BodyLandmarks {
        func mean(_ key: KeyPath<BodyLandmarks, BodyPoint?>) -> BodyPoint? {
            let values = samples.compactMap { $0[keyPath: key] }
            guard values.count >= max(1, samples.count / 3) else { return nil }
            return BodyPoint(x: values.map(\.x).reduce(0, +) / Double(values.count), y: values.map(\.y).reduce(0, +) / Double(values.count))
        }
        return BodyLandmarks(nose: mean(\.nose), leftEye: mean(\.leftEye), rightEye: mean(\.rightEye), leftEar: mean(\.leftEar),
                             rightEar: mean(\.rightEar), leftShoulder: mean(\.leftShoulder), rightShoulder: mean(\.rightShoulder),
                             leftHip: mean(\.leftHip), rightHip: mean(\.rightHip))
    }
}
