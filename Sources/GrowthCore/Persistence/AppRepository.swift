import Foundation
import Observation

public enum RepositoryState: Equatable, Sendable {
    case ready
    /// Saved data couldn't be read. The app shows recovery options instead of silently wiping data.
    case unreadableData(String)
}

/// Owns the in-memory snapshot and writes every change through to the store.
@MainActor
@Observable
public final class AppRepository {
    public private(set) var snapshot: AppSnapshot
    public private(set) var state: RepositoryState
    /// Last save error, surfaced as a non-blocking banner. Data stays in memory and is retried on the next change.
    public private(set) var lastSaveError: String?

    @ObservationIgnored private let store: ProfileStore

    public init(store: ProfileStore) {
        self.store = store
        switch store.load() {
        case .empty:
            snapshot = .empty
            state = .ready
        case .loaded(let loaded):
            snapshot = loaded
            state = .ready
        case .unreadable(let message):
            snapshot = .empty
            state = .unreadableData(message)
        }
    }

    public var activeProfile: GrowthProfile? { snapshot.activeProfile }
    public var profiles: [GrowthProfile] { snapshot.profiles }

    public func update(_ mutate: (inout AppSnapshot) -> Void) {
        var copy = snapshot
        mutate(&copy)
        snapshot = copy
        persist()
    }

    private func persist() {
        do {
            try store.save(snapshot)
            lastSaveError = nil
        } catch {
            lastSaveError = String(describing: error)
        }
    }

    // MARK: Onboarding

    public func saveDraft(_ draft: OnboardingDraft?) {
        update { $0.onboardingDraft = draft }
    }

    public func acknowledgePrivacy(at date: Date) {
        update { $0.privacyAcknowledgement = PrivacyAcknowledgement(acknowledgedAt: date) }
    }

    /// Adds the profile, makes it active and clears the draft in a single write.
    public func completeOnboarding(with profile: GrowthProfile) {
        update {
            $0.profiles.append(profile)
            $0.activeProfileID = profile.id
            $0.onboardingDraft = nil
        }
    }

    // MARK: Profiles

    public func setActiveProfile(_ id: UUID) {
        guard snapshot.profiles.contains(where: { $0.id == id }) else { return }
        update { $0.activeProfileID = id }
    }

    public func addMeasurement(_ measurement: HeightMeasurement, to profileID: UUID, at date: Date) {
        update { snapshot in
            guard let index = snapshot.profiles.firstIndex(where: { $0.id == profileID }) else { return }
            snapshot.profiles[index].measurements.append(measurement)
            snapshot.profiles[index].measurements.sort { $0.date < $1.date }
            snapshot.profiles[index].updatedAt = date
        }
    }

    public func deleteMeasurement(_ measurementID: UUID, from profileID: UUID, at date: Date) {
        update { snapshot in
            guard let index = snapshot.profiles.firstIndex(where: { $0.id == profileID }) else { return }
            // Never delete the last remaining measurement: a profile always has a current height.
            guard snapshot.profiles[index].measurements.count > 1 else { return }
            snapshot.profiles[index].measurements.removeAll { $0.id == measurementID }
            snapshot.profiles[index].updatedAt = date
        }
    }

    public func updateMeasurement(_ measurement: HeightMeasurement, in profileID: UUID, at date: Date) {
        update { snapshot in
            guard let index = snapshot.profiles.firstIndex(where: { $0.id == profileID }),
                  let m = snapshot.profiles[index].measurements.firstIndex(where: { $0.id == measurement.id }) else { return }
            snapshot.profiles[index].measurements[m] = measurement
            snapshot.profiles[index].measurements.sort { $0.date < $1.date }
            snapshot.profiles[index].updatedAt = date
        }
    }

    /// Replaces a profile (after an edit). Measurements are kept sorted.
    public func updateProfile(_ profile: GrowthProfile, at date: Date) {
        update { snapshot in
            guard let index = snapshot.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
            var updated = profile
            updated.measurements.sort { $0.date < $1.date }
            updated.updatedAt = date
            snapshot.profiles[index] = updated
        }
    }

    /// Deletes one profile. If it was active, the first remaining profile becomes active.
    /// Deleting the last profile returns the app to onboarding.
    public func deleteProfile(_ id: UUID) {
        update { snapshot in
            snapshot.profiles.removeAll { $0.id == id }
            if snapshot.activeProfileID == id { snapshot.activeProfileID = snapshot.profiles.first?.id }
        }
    }

    public func setUnitPreference(_ unit: HeightUnit, for profileID: UUID) {
        update { snapshot in
            guard let index = snapshot.profiles.firstIndex(where: { $0.id == profileID }) else { return }
            snapshot.profiles[index].unitPreference = unit
        }
    }

    // MARK: Recovery & deletion

    public func startFreshAfterUnreadableData() throws {
        try store.quarantineUnreadableData()
        snapshot = .empty
        state = .ready
    }

    public func deleteAllData() throws {
        try store.deleteAll()
        snapshot = .empty
        state = .ready
        lastSaveError = nil
    }
}
