#if os(iOS)
import Foundation
import Observation
import GrowthCore

/// Why the paywall was opened. Changes only the first line, so the person knows what they tapped.
public enum PaywallContext: String, Identifiable, Sendable {
    case general, report, analysis, family
    public var id: String { rawValue }

    var intro: String? {
        switch self {
        case .general: return nil
        case .report: return "The doctor-ready report is part of Premium."
        case .analysis: return "Advanced growth analysis is part of Premium."
        case .family: return "Adding another profile is part of Premium. Profiles you already have always stay free to use."
        }
    }
}

/// App-level presentation state shared by the tabs: the paywall, notification routes and the weekly summary.
@MainActor
@Observable
public final class AppNavigator {
    public var paywall: PaywallContext?
    public var route: NotificationRoute?
    public var showsWeeklySummary = false

    public init() {}

    public func showPaywall(_ context: PaywallContext = .general) {
        paywall = context
    }

    public func open(_ route: NotificationRoute) {
        if route == .weeklySummary {
            showsWeeklySummary = true
        } else {
            self.route = route
        }
    }
}
#endif
