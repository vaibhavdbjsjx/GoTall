import Foundation
import Observation

public enum AssistantAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceOff
    case modelNotReady
    case unsupportedOS

    public var isAvailable: Bool { self == .available }

    /// Shown when answers come from the built-in guide instead of the on-device model.
    public var explanation: String? {
        switch self {
        case .available: return nil
        case .deviceNotEligible: return "This iPhone doesn't support Apple Intelligence, so answers come from Linden's built-in guide."
        case .appleIntelligenceOff: return "Turn on Apple Intelligence in Settings for conversational answers. Until then, answers come from Linden's built-in guide."
        case .modelNotReady: return "Apple Intelligence is still getting ready on this iPhone. Answers come from Linden's built-in guide for now."
        case .unsupportedOS: return "Conversational answers need iOS 26 with Apple Intelligence. Answers come from Linden's built-in guide."
        }
    }
}

/// The on-device language model (Apple Foundation Models in the app; fakes in tests).
@MainActor
public protocol AssistantModel: AnyObject {
    var availability: AssistantAvailability { get }
    func respond(instructions: String, prompt: String) async throws -> String
}

/// Counts free questions per day.
@MainActor
public protocol AssistantUsageStore: AnyObject {
    func count(on day: String) -> Int
    func increment(on day: String)
}

@MainActor
public final class InMemoryAssistantUsageStore: AssistantUsageStore {
    var counts: [String: Int] = [:]
    public init() {}
    public func count(on day: String) -> Int { counts[day, default: 0] }
    public func increment(on day: String) { counts[day, default: 0] += 1 }
}

@MainActor
public final class DefaultsAssistantUsageStore: AssistantUsageStore {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func count(on day: String) -> Int { defaults.integer(forKey: "assistant.count.\(day)") }
    public func increment(on day: String) { defaults.set(count(on: day) + 1, forKey: "assistant.count.\(day)") }
}

/// A conversation with Ask Linden. Every question goes through: safety check → free-question allowance →
/// on-device model (if available) → output guard → built-in guide as the fallback. Nothing leaves the device.
@MainActor
@Observable
public final class AssistantSession {
    public enum Source: String, Sendable { case onDevice, guide, safety, system }
    public enum Role: Sendable { case user, assistant }

    public struct Message: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let role: Role
        public let text: String
        public let source: Source?
        /// True for the message that explains the daily free limit (the UI offers Premium under it).
        public let isLimitNotice: Bool

        init(role: Role, text: String, source: Source? = nil, isLimitNotice: Bool = false) {
            id = UUID()
            self.role = role
            self.text = text
            self.source = source
            self.isLimitNotice = isLimitNotice
        }
    }

    public static let freeDailyQuestions = 3
    public static let maximumQuestionLength = 500

    public private(set) var messages: [Message] = []
    public private(set) var isThinking = false

    @ObservationIgnored private let model: AssistantModel?
    @ObservationIgnored private let usage: AssistantUsageStore
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(model: AssistantModel?, usage: AssistantUsageStore, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.model = model
        self.usage = usage
        self.calendar = calendar
        self.now = now
    }

    public var availability: AssistantAvailability { model?.availability ?? .unsupportedOS }

    /// Free questions left today, or `nil` when unlimited (Premium).
    public func remainingFree(isPremium: Bool) -> Int? {
        isPremium ? nil : max(0, Self.freeDailyQuestions - usage.count(on: dayKey))
    }

    var dayKey: String {
        let c = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func send(_ raw: String, facts: AssistantFacts, isPremium: Bool) async {
        let question = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumQuestionLength))
        guard !question.isEmpty, !isThinking else { return }
        messages.append(Message(role: .user, text: question))

        // Safety answers are always given and never count against the free allowance.
        if case .fixed(_, let text) = AssistantSafety.classify(question) {
            messages.append(Message(role: .assistant, text: text, source: .safety))
            return
        }

        if !isPremium && usage.count(on: dayKey) >= Self.freeDailyQuestions {
            messages.append(Message(role: .assistant,
                                    text: "That's today's \(Self.freeDailyQuestions) free questions. They reset tomorrow, or Premium gives unlimited questions. Everything else in the app stays free.",
                                    source: .system, isLimitNotice: true))
            return
        }

        isThinking = true
        defer { isThinking = false }
        let (text, source) = await answer(question, facts: facts)
        usage.increment(on: dayKey)
        messages.append(Message(role: .assistant, text: text, source: source))
    }

    func answer(_ question: String, facts: AssistantFacts) async -> (String, Source) {
        if let model, model.availability.isAvailable {
            do {
                let reply = try await model.respond(instructions: AssistantPrompt.instructions(facts: facts), prompt: question)
                if AssistantOutputGuard.check(reply, brief: facts.brief) == nil {
                    return (reply.trimmingCharacters(in: .whitespacesAndNewlines), .onDevice)
                }
            } catch {
                // Model errors (guardrails, context, not ready) fall through to the guide.
            }
        }
        return (AssistantGuide.answer(question, facts: facts), .guide)
    }

    public func clear() {
        messages.removeAll()
    }
}
