import XCTest
@testable import GrowthCore

/// Release checks that don't need a device: brand consistency, legal text, and the public site.
final class ReleaseTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testBrandIsConsistent() throws {
        XCTAssertEqual(BrandConfig.current.displayName, "Stature")
        XCTAssertEqual(CopyGuard.violations(in: BrandConfig.current.tagline), [])
        let project = try String(contentsOf: Self.root.appendingPathComponent("App/project.yml"), encoding: .utf8)
        XCTAssertTrue(project.contains("APP_DISPLAY_NAME: \"\(BrandConfig.current.displayName)\""), "project display name matches BrandConfig")
        XCTAssertTrue(project.contains("MARKETING_VERSION: \"1.0.0\""))
        let storekit = try String(contentsOf: Self.root.appendingPathComponent("App/Products.storekit"), encoding: .utf8)
        for id in SubscriptionProductID.all { XCTAssertTrue(storekit.contains("\"\(id)\""), id) }
        XCTAssertTrue(SubscriptionProductID.all.allSatisfy { $0.hasPrefix("app.stature.height.") })
    }

    func testLegalTextIsHonestAndComplete() {
        let privacy = LegalDocument.privacy.plainText
        for required in ["don't collect", "no ads", "Apple", "Delete all data", "under 13", "on your device"] {
            XCTAssertTrue(privacy.contains(required), required)
        }
        let terms = LegalDocument.terms.plainText
        for required in ["not medical advice", "24 hours", "cancel", "stdeula", "not guarantees"] {
            XCTAssertTrue(terms.lowercased().contains(required.lowercased()), required)
        }
        XCTAssertEqual(CopyGuard.violations(in: privacy + terms), [])
    }

    func testPublicSiteMatchesInAppLegalText() throws {
        for (doc, file) in [(LegalDocument.privacy, "site/privacy.html"), (LegalDocument.terms, "site/terms.html")] {
            let raw = try String(contentsOf: Self.root.appendingPathComponent(file), encoding: .utf8)
            let html = raw.replacingOccurrences(of: "&#x27;", with: "'").replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
            for section in doc.sections {
                XCTAssertTrue(html.contains(section.title), "\(file) is missing '\(section.title)'. Run scripts/build_site.py")
                for paragraph in section.paragraphs {
                    XCTAssertTrue(html.contains(paragraph), "\(file) is out of date. Run scripts/build_site.py")
                }
            }
        }
    }

    func testPrivacyManifestDeclaresNoTracking() throws {
        let manifest = try String(contentsOf: Self.root.appendingPathComponent("App/Resources/PrivacyInfo.xcprivacy"), encoding: .utf8)
        XCTAssertTrue(manifest.contains("<key>NSPrivacyTracking</key>\n\t<false/>"))
        XCTAssertTrue(manifest.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
        XCTAssertTrue(manifest.contains("CA92.1"))
    }
}
