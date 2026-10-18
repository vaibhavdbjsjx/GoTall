#if os(iOS)
import Foundation
import GrowthCore
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Ask Linden's language model: Apple's on-device foundation model (iOS 26+, Apple Intelligence).
/// Runs entirely on the iPhone: no API key, no server, no data leaves the device.
/// On older iOS versions or ineligible devices `availability` says why, and the built-in guide answers instead.
@MainActor
public final class OnDeviceAssistantModel: AssistantModel {
    public enum ModelError: Error { case unavailable }

    public init() {}

    public var availability: AssistantAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return .deviceNotEligible
                case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
                case .modelNotReady: return .modelNotReady
                @unknown default: return .modelNotReady
                }
            @unknown default:
                return .modelNotReady
            }
        }
        #endif
        return .unsupportedOS
    }

    public func respond(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            // A fresh session per question: each answer is grounded only in the current facts.
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw ModelError.unavailable
    }
}
#endif
