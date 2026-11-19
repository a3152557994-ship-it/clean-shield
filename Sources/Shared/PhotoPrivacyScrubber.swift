import Foundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

public struct PhotoPrivacyReport: Equatable, Sendable {
    public let hasGPS: Bool
    public let latitude: Double?
    public let longitude: Double?
    public let deviceModel: String?
    public let lensModel: String?
    public let captureTimestamp: String?
    public let pixelWidth: Int
    public let pixelHeight: Int

    public var riskCount: Int {
        var count = 0
        if hasGPS { count += 1 }
        if deviceModel != nil || lensModel != nil { count += 1 }
        if captureTimestamp != nil { count += 1 }
        return count
    }
}

public enum PhotoPrivacyScrubber {

    public static func inspect(imageData: Data) -> PhotoPrivacyReport? {
        guard let src = CGImageSourceCreateWithData(imageData as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let width = (props[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? Int) ?? 0

        let gpsDict = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        var lat = gpsDict?[kCGImagePropertyGPSLatitude] as? Double
        if let ref = gpsDict?[kCGImagePropertyGPSLatitudeRef] as? String, ref.uppercased() == "S", let v = lat {
            lat = -abs(v)
        }
        var lon = gpsDict?[kCGImagePropertyGPSLongitude] as? Double
        if let ref = gpsDict?[kCGImagePropertyGPSLongitudeRef] as? String, ref.uppercased() == "W", let v = lon {
            lon = -abs(v)
        }
        let hasGPS = (gpsDict != nil && !(gpsDict!.isEmpty))

        let tiffDict = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exifDict = props[kCGImagePropertyExifDictionary] as? [CFString: Any]

        let model = tiffDict?[kCGImagePropertyTIFFModel] as? String
        let lens = exifDict?[kCGImagePropertyExifLensModel] as? String
        let dateStr = (exifDict?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (tiffDict?[kCGImagePropertyTIFFDateTime] as? String)

        return PhotoPrivacyReport(
            hasGPS: hasGPS,
            latitude: lat,
            longitude: lon,
            deviceModel: model,
            lensModel: lens,
            captureTimestamp: dateStr,
            pixelWidth: width,
            pixelHeight: height
        )
    }

    /// Re-encodes pixels cleanly without GPS, EXIF, TIFF, or IPTC privacy dictionaries while preserving visual orientation.
    public static func stripMetadata(from imageData: Data, compressionQuality: CGFloat = 0.94) -> Data? {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: imageData) {
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1.0
            format.opaque = true
            let pixelSize = CGSize(
                width: max(1, round(uiImage.size.width * uiImage.scale)),
                height: max(1, round(uiImage.size.height * uiImage.scale))
            )
            let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
            let cleanImage = renderer.image { ctx in
                UIColor.black.setFill()
                ctx.fill(CGRect(origin: .zero, size: pixelSize))
                uiImage.draw(in: CGRect(origin: .zero, size: pixelSize))
            }
            if let jpeg = cleanImage.jpegData(compressionQuality: compressionQuality) {
                return jpeg
            }
        }
        #endif

        guard let src = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return nil
        }
        let outData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(outData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return outData as Data
    }
}
