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

    public static let effective = "21 October 2026"

    public static var privacy: LegalDocument {
        let name = BrandConfig.current.displayName
        return LegalDocument(id: "privacy", title: "Privacy Policy", effectiveDate: effective, sections: [
            Section(title: "In short", paragraphs: [
                "\(name) keeps your growth data on your device. An account is optional. If you don't create one, we, the developer, don't collect, receive, sell or share personal data. If you do create one to back up your profiles, we keep your email address and that backup only to provide the backup. There are no ads, no analytics and no tracking."
            ]),
            Section(title: "What the app stores on your device", paragraphs: [
                "Profiles you create: an optional nickname, birth date, the growth chart used (female or male), height measurements, optional parents' heights, habit check-ins, routines you complete, posture-check scores, bedtime settings, food-group check-ins, optional puberty-check answers and your preferences.",
                "This data is saved on your device with iOS data protection. Unless you sign in to back it up, it is not sent to us or to any server."
            ]),
            Section(title: "Optional account and backup", paragraphs: [
                "You can sign in with Apple or with an email and password. If you do, we store your email address (Sign in with Apple lets you hide your real one) and a copy of the data listed above, so you can restore it on another iPhone. It is sent over an encrypted connection and stored by our hosting provider, Supabase, in a database where each account can only read its own backup.",
                "We use the backup only to back up and restore your data. We never sell it, share it or use it for advertising. You can delete your account and its backup at any time in Profile › Account › Delete account."
            ]),
            Section(title: "Camera and posture check", paragraphs: [
                "The posture check uses the front camera. Each frame is analysed on your device with Apple's Vision framework and then discarded. No photo or video is saved or sent. Only the resulting score and alignment readings are kept with the profile."
            ]),
            Section(title: "\(BrandConfig.current.assistantName)", paragraphs: [
                "Questions are answered on your device, using Apple's on-device model where available or \(name)'s built-in guide. Your questions and the answers are not sent to us or to anyone else, and conversations are not saved after you close them. The app only keeps a count of questions asked each day."
            ]),
            Section(title: "Purchases", paragraphs: [
                "Subscriptions and the lifetime purchase are processed by Apple. We don't receive your name, email or payment details from Apple. The app checks your purchase status on your device using Apple's StoreKit. Apple's privacy policy applies to purchases."
            ]),
            Section(title: "Reminders, reports and exports", paragraphs: [
                "Reminders are scheduled on your device. Reports (PDF) and data exports (JSON) are created on your device and are only shared if you choose to share them."
            ]),
            Section(title: "Children", paragraphs: [
                "\(name) is designed for parents and caregivers to track a child's growth, and for teenagers and adults to track their own. Profiles for children under 13 are created and managed by a parent, and a child's data is only backed up if the parent signs in with their own account. We don't knowingly let children under 13 create accounts."
            ]),
            Section(title: "Backups and deleting your data", paragraphs: [
                "You can delete everything on your device at any time in Profile › Privacy & data › Delete all data. Deleting the app also removes its data from the device. Deleting your account removes its backup from our server. If you use iCloud Backup, Apple may include app data in your device backup according to your iCloud settings."
            ]),
            Section(title: "Changes and contact", paragraphs: [
                "If this policy changes, the new version will appear in the app and on our website with a new effective date. Questions: privacy@stature.app."
            ])
        ])
    }

    public static var terms: LegalDocument {
        let name = BrandConfig.current.displayName
        return LegalDocument(id: "terms", title: "Terms of Use", effectiveDate: effective, sections: [
            Section(title: "Not medical advice", paragraphs: [
                "\(name) shows measurements and growth-chart context for information. It does not diagnose, treat or prevent any condition. Estimates are not guarantees. Routines and the posture check support everyday posture and mobility habits; they don't change bone length. Talk to a doctor or other qualified health professional about any health concern, and stop any exercise that causes pain."
            ]),
            Section(title: "Stature Pro", paragraphs: [
                "Stature Pro is sold by Apple as an auto-renewable subscription (weekly, monthly or yearly) or as a one-time lifetime purchase. The price and billing period are shown before you buy. Payment is charged to your Apple Account. A subscription renews automatically unless cancelled at least 24 hours before the end of the current period. You can manage or cancel it in Settings › Apple Account › Subscriptions. A free trial, if offered, converts to a paid subscription unless cancelled before it ends. Deleting the app, its data or your account does not cancel a subscription.",
                "Apple's Standard Licensed Application End User License Agreement applies: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
            ]),
            Section(title: "Accounts", paragraphs: [
                "An account is optional and only used for backup. Keep your password safe. You can delete your account at any time in the app."
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
