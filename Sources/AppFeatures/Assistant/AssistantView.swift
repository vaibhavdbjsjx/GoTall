#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

/// Ask Linden: questions about this profile's growth, answered on the iPhone. Grounded in the same numbers as
/// the rest of the app, guarded against invented numbers and medical claims, never sent anywhere.
struct AssistantView: View {
    let repository: AppRepository
    var initialQuestion: String?

    @Environment(AssistantSession.self) private var session
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var paywall: PaywallContext?
    @State private var askedInitial = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let profile = repository.activeProfile {
                    conversation(AssistantFacts(profile: profile, now: Date(), calendar: .current))
                } else {
                    EmptyStateView(systemImage: "sparkles", title: "No profile yet", message: "Add a profile to ask about growth.")
                }
            }
            .dsPageBackground()
            .navigationTitle(BrandConfig.current.assistantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if !session.messages.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { withAnimation(Motion.standard) { session.clear() } } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel("New conversation")
                    }
                }
            }
            .paywallSheet($paywall)
        }
    }

    private func conversation(_ facts: AssistantFacts) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if session.messages.isEmpty {
                        AssistantHero(facts: facts, availability: session.availability)
                            .appearEffect()
                        suggestions(facts)
                    } else {
                        ForEach(session.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            if message.isLimitNotice {
                                AppButton("Explore Premium", systemImage: "sparkles", kind: .secondary) { paywall = .general }
                                    .accessibilityIdentifier("assistant.explorePremium")
                            }
                        }
                        if session.isThinking {
                            ThinkingIndicator().id("thinking")
                        }
                    }
                    Text("Not medical advice. Answers use \(facts.possessive) saved measurements, stay on this iPhone and never change any number in the app.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DS.Spacing.xs)
                        .id("bottom")
                }
                .padding(.horizontal, DS.Spacing.page)
                .padding(.vertical, DS.Spacing.md)
                .animation(Motion.standard, value: session.messages.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.messages.count) { _, _ in
                withAnimation(Motion.standard) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: session.isThinking) { _, thinking in
                if thinking { withAnimation(Motion.standard) { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { inputBar(facts) }
            .task {
                guard !askedInitial else { return }
                askedInitial = true
                var questions = initialQuestion.map { [$0] } ?? []
                #if DEBUG
                // Screenshot harness: `-assistantAsk "First question|Second question"`.
                if questions.isEmpty, let scripted = UserDefaults.standard.string(forKey: "assistantAsk") {
                    questions = scripted.components(separatedBy: "|")
                }
                #endif
                for question in questions { await ask(question, facts: facts) }
            }
        }
    }

    private func suggestions(_ facts: AssistantFacts) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Try asking").font(DS.Typography.eyebrow).foregroundStyle(DS.Colors.textTertiary)
            FlowLayout(spacing: DS.Spacing.xs) {
                ForEach(Array(AssistantGuide.suggestions(for: facts).enumerated()), id: \.offset) { index, question in
                    Button { Task { await ask(question, facts: facts) } } label: {
                        Text(question)
                            .font(DS.Typography.subheadline.weight(.medium))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .frame(minHeight: DS.minimumTapTarget)
                            .foregroundStyle(DS.Colors.accent)
                            .background(DS.Colors.accentSoft, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("assistant.suggestion.\(index)")
                }
            }
        }
    }

    private func inputBar(_ facts: AssistantFacts) -> some View {
        VStack(spacing: 6) {
            if let remaining = session.remainingFree(isPremium: entitlements.access(.unlimitedAssistant) == .available) {
                Button { if remaining == 0 { paywall = .general } } label: {
                    Text(remaining == 0 ? "No free questions left today · Premium is unlimited"
                                        : "\(remaining) free question\(remaining == 1 ? "" : "s") left today · Premium is unlimited")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("assistant.remaining")
            }
            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                TextField("Ask about growth…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(DS.Colors.separator, lineWidth: 1))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { send(facts) }
                    .accessibilityIdentifier("assistant.input")
                Button { send(facts) } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(canSend ? DS.Colors.accent : DS.Colors.separator)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("assistant.send")
            }
        }
        .padding(.horizontal, DS.Spacing.page)
        .padding(.top, DS.Spacing.xs)
        .padding(.bottom, DS.Spacing.xs)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !session.isThinking
    }

    private func send(_ facts: AssistantFacts) {
        guard canSend else { return }
        let question = draft
        draft = ""
        Task { await ask(question, facts: facts) }
    }

    private func ask(_ question: String, facts: AssistantFacts) async {
        await session.send(question, facts: facts, isPremium: entitlements.access(.unlimitedAssistant) == .available)
        if let last = session.messages.last, last.role == .assistant {
            UIAccessibility.post(notification: .announcement, argument: last.text)
        }
    }
}

/// Empty-state header: what this is, how private it is, and which engine is answering.
private struct AssistantHero: View {
    let facts: AssistantFacts
    let availability: AssistantAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                AssistantOrb(size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(BrandConfig.current.assistantName).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Badge(availability.isAvailable ? "On-device AI · Private" : "Built-in guide · Private", tone: .accent)
                        .accessibilityIdentifier("assistant.mode")
                }
            }
            Text("Ask anything about \(facts.possessive) growth: the estimate, percentiles, growth speed, sleep, food, activity or measuring. Answers use the same numbers as the rest of the app.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let explanation = availability.explanation {
                Label(explanation, systemImage: "info.circle")
                    .font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroSurface()
    }
}

/// The assistant's mark: a soft spruce orb with sparkles. Gently breathes; still under Reduce Motion.
struct AssistantOrb: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [DS.Colors.accent.opacity(0.35), DS.Colors.accent.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.7))
                .scaleEffect(pulse ? 1.12 : 0.96)
            Circle()
                .fill(LinearGradient(colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.78, height: size * 0.78)
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(DS.Colors.onAccent)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

private struct MessageBubble: View {
    let message: AssistantSession.Message

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: DS.Spacing.xxl)
                Text(message.text)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.onAccent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You asked: \(message.text)")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let label = sourceLabel {
                    Label(label.text, systemImage: label.symbol)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsSurface(radius: 20)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("assistant.answer")
        }
    }

    private var sourceLabel: (text: String, symbol: String)? {
        switch message.source {
        case .onDevice: return ("On-device AI, checked against your numbers", "sparkles")
        case .guide: return ("\(BrandConfig.current.displayName) guide", "book.closed")
        case .safety: return ("Safety answer", "heart")
        case .system, .none: return nil
        }
    }
}

private struct ThinkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DS.Colors.accent)
                    .frame(width: 8, height: 8)
                    .opacity(reduceMotion ? 0.6 : 0.35 + 0.65 * max(0, sin(phase + Double(i) * 0.9)))
            }
            Text("Thinking").font(DS.Typography.caption).foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(DS.Spacing.md)
        .dsSurface(radius: 20)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi * 2 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
    }
}

/// Home entry: the assistant as a calm, inviting card with two one-tap questions.
struct AskLindenCard: View {
    let facts: AssistantFacts
    let onAsk: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button { onAsk(nil) } label: {
                HStack(spacing: DS.Spacing.md) {
                    AssistantOrb(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(BrandConfig.current.assistantName).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                        Text("Questions about \(facts.possessive) growth, answered privately on this iPhone.")
                            .font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(DS.Colors.textTertiary)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("home.ask")
            FlowLayout(spacing: DS.Spacing.xs) {
                ForEach(AssistantGuide.suggestions(for: facts).prefix(2), id: \.self) { question in
                    Button { onAsk(question) } label: {
                        Text(question)
                            .font(DS.Typography.footnote.weight(.medium))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 7)
                            .foregroundStyle(DS.Colors.accent)
                            .background(DS.Colors.accentSoft, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsSurface()
    }
}
#endif
