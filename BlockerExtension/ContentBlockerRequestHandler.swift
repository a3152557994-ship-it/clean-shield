import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupID)
        let dynamicURL = groupContainer?.appendingPathComponent(SharedConstants.compiledRulesFilename)

        let targetURL: URL?
        if let dynamicURL, FileManager.default.fileExists(atPath: dynamicURL.path) {
            targetURL = dynamicURL
        } else {
            // Generate fresh default rules if shared file does not exist yet
            if let freshURL = try? BlockerRuleCompiler.writeToSharedContainer(config: ShieldBlockerConfig(), isPro: false),
               FileManager.default.fileExists(atPath: freshURL.path) {
                targetURL = freshURL
            } else {
                targetURL = Bundle.main.url(forResource: "blockerList", withExtension: "json")
            }
        }

        guard let finalURL = targetURL,
              let attachment = NSItemProvider(contentsOf: finalURL) else {
            context.cancelRequest(withError: NSError(domain: "CleanShieldBlocker", code: -1))
            return
        }

        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
