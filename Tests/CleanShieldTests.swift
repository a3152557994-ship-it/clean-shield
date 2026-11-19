import XCTest
import ImageIO
import UniformTypeIdentifiers
import UIKit
@testable import CleanShield

final class CleanShieldTests: XCTestCase {

    func testBlockerRuleOrderingPlacesIronWhitelistLast() throws {
        var config = ShieldBlockerConfig()
        config.customBlockedDomains = ["https://ads.badtracker.org/banner"]
        config.customWhitelistDomains = ["mybank.example.com"]
        config.blockJumpBannersPro = true

        let data = try BlockerRuleCompiler.compileJSONData(config: config, isPro: true)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(parsed)
        guard let rules = parsed else { return }
        XCTAssertGreaterThan(rules.count, 50)

        // Verify the very last rules are `ignore-previous-rules` so banking/maps can never be broken
        let lastAction = (rules.last?["action"] as? [String: Any])?["type"] as? String
        XCTAssertEqual(lastAction, "ignore-previous-rules")

        // Verify custom blocked domain was sanitized and included before whitelist
        let allFilters = rules.compactMap { ($0["trigger"] as? [String: Any])?["url-filter"] as? String }
        XCTAssertTrue(allFilters.contains(where: { $0.contains("ads\\.badtracker\\.org") }))
        XCTAssertTrue(allFilters.contains(where: { $0.contains("mybank\\.example\\.com") }))
    }

    func testPhotoPrivacyScrubberStripsGPSAndEXIF() throws {
        // Create an opaque synthetic image with injected GPS & TIFF dictionaries
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1.0
        fmt.opaque = true
        let img = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 90), format: fmt).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 90))
        }
        let cgImg = try XCTUnwrap(img.cgImage)

        let rawWithGPS = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(rawWithGPS, UTType.png.identifier as CFString, 1, nil))
        let dirtyProps: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 30.2741,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 120.1551,
                kCGImagePropertyGPSLongitudeRef: "E"
            ],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFModel: "iPhone 17 Pro"
            ]
        ]
        CGImageDestinationAddImage(dest, cgImg, dirtyProps as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))

        let beforeReport = try XCTUnwrap(PhotoPrivacyScrubber.inspect(imageData: rawWithGPS as Data))
        XCTAssertTrue(beforeReport.hasGPS)
        XCTAssertEqual(beforeReport.deviceModel, "iPhone 17 Pro")

        let scrubbed = try XCTUnwrap(PhotoPrivacyScrubber.stripMetadata(from: rawWithGPS as Data))
        let afterReport = try XCTUnwrap(PhotoPrivacyScrubber.inspect(imageData: scrubbed))
        XCTAssertFalse(afterReport.hasGPS)
        XCTAssertNil(afterReport.latitude)
        XCTAssertNil(afterReport.deviceModel)
        XCTAssertEqual(afterReport.pixelWidth, 120)
        XCTAssertEqual(afterReport.pixelHeight, 90)
    }

    func testAuditCatalogCompletenessAndScoring() {
        XCTAssertEqual(AuditCatalog.items.count, 30)
        let freeItems = AuditCatalog.items.filter(\.isFreeTier)
        XCTAssertEqual(freeItems.count, 10)

        let emptyScore = AuditCatalog.calculateScore(completedIDs: [])
        XCTAssertEqual(emptyScore, 15)

        let fullIDs = Set(AuditCatalog.items.map(\.id))
        let fullScore = AuditCatalog.calculateScore(completedIDs: fullIDs)
        XCTAssertEqual(fullScore, 100)
    }
}
