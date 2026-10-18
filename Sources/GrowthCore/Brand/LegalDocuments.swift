import Foundation

/// Privacy policy and terms, shown in the app (works offline) and mirrored in `site/` for App Store Connect.
/// Written to match what the code actually does. Have it reviewed by a qualified lawyer before release
/// (docs/release-checklist.md).
public struct LegalDocument: Sendable, Equatable, Identifiable {
    public struct Section: Sendable, Equatable, Identifiable {
        public var title: String
        public var paragraphs: [String]
        public var id: String { title }
    }

    public var id: String
    public var title: String
    public var effectiveDate: String
    public var sections: [Section]

    public static let effective = "18 October 2026"

    public static var privacy: LegalDocument {
        let name = BrandConfig.current.displayName
        return LegalDocument(id: "privacy", title: "Privacy Policy", effectiveDate: effective, sections: [
            Section(title: "In short", paragraphs: [
                "\(name) keeps your growth data on your iPhone. We, the developer, don't collect, receive, sell or share personal data. There are no accounts, no ads, no analytics and no tracking."
            ]),
            Section(title: "What the app stores on your device", paragraphs: [
                "Profiles you create: an optional nickname, birth date, the growth chart used (female or male), height measurements, optional parents' heights, habit check-ins and your preferences.",
                "This data is saved on your device with iOS data protection. It is not sent to us or to any server we run; \(name) has no server."
            ]),
            Section(title: "\(BrandConfig.current.assistantName)", paragraphs: [
                "Questions are answered on your device, using Apple's on-device model where available or \(name)'s built-in guide. Your questions and the answers are not sent to us or to anyone else, and conversations are not saved after you close them. The app only keeps a count of questions asked each day."
            ]),
            Section(title: "Purchases", paragraphs: [
                "Subscriptions are processed by Apple. We don't receive your name, email or payment details. The app checks your subscription status on your device using Apple's StoreKit. Apple's privacy policy applies to purchases."
            ]),
            Section(title: "Reminders, reports and exports", paragraphs: [
                "Reminders are scheduled on your device. Reports (PDF) and data exports (JSON) are created on your device and are only shared if you choose to share them."
            ]),
            Section(title: "Children", paragraphs: [
                "\(name) is designed for parents and caregivers to track a child's growth, and for teenagers and adults to track their own. Profiles for children under 13 are created and managed by a parent. Because we collect no personal information from anyone, we collect none from children."
            ]),
            Section(title: "Backups and deleting your data", paragraphs: [
                "You can delete everything at any time in Profile › Privacy & data › Delete all data. Deleting the app also removes its data from the device. If you use iCloud Backup, Apple may include app data in your device backup according to your iCloud settings."
            ]),
            Section(title: "Changes and contact", paragraphs: [
                "If this policy changes, the new version will appear in the app and on our website with a new effective date. Questions: see the support page linked in the app and on the App Store."
            ])
        ])
    }

    public static var terms: LegalDocument {
        let name = BrandConfig.current.displayName
        return LegalDocument(id: "terms", title: "Terms of Use", effectiveDate: effective, sections: [
            Section(title: "Not medical advice", paragraphs: [
                "\(name) shows measurements and growth-chart context for information. It does not diagnose, treat or prevent any condition. Estimates are not guarantees. Talk to a doctor or other qualified health professional about any health concern."
            ]),
            Section(title: "Subscriptions", paragraphs: [
                "Premium is an auto-renewable subscription sold by Apple. The price and billing period are shown before you buy. Payment is charged to your Apple Account. It renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it in Settings › Apple Account › Subscriptions. Deleting the app or its data does not cancel a subscription.",
                "Apple's Standard Licensed Application End User License Agreement applies: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
            ]),
            Section(title: "Using the app", paragraphs: [
                "Use \(name) for personal, non-commercial purposes. Enter information you have the right to enter, such as your own or your child's measurements.",
                "The app is provided as is. To the extent permitted by law, we are not liable for decisions made based on information shown in the app."
            ]),
            Section(title: "Changes", paragraphs: [
                "We may update these terms. The current version is always available in the app with its effective date."
            ])
        ])
    }

    /// Plain text, for tests and copy checks.
    public var plainText: String {
        ([title, effectiveDate] + sections.flatMap { [$0.title] + $0.paragraphs }).joined(separator: "\n")
    }
}
