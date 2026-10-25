import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Guards against PNG pixel bombs: small compressed files that expand to huge bitmaps.
enum SafePNGValidator {
    static let maxPixelDimension = 8192
    static let maxPixelCount = 16_777_216 // 16 MP

    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    enum ValidationError: Error {
        case invalidImage
        case dimensionsTooLarge
    }

    static func validatePNGData(_ data: Data) throws {
        _ = try validatedSource(data)
    }

    /// Returns an image source only for a single-image PNG within the pixel caps. ImageIO
    /// sniffs content, so without the signature and type checks a TIFF, JPEG, or multi-frame
    /// file named `.png` would reach its decoder.
    private static func validatedSource(_ data: Data) throws -> CGImageSource {
        guard data.starts(with: pngSignature) else {
            throw ValidationError.invalidImage
        }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              CGImageSourceGetType(source) as String? == UTType.png.identifier,
              CGImageSourceGetCount(source) == 1,
              let props = CGImageSourceCopyPropertiesAtIndex(
                  source,
                  0,
                  options
              ) as? [CFString: Any]
        else {
            throw ValidationError.invalidImage
        }
        let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard isAllowedPixelSize(width: width, height: height) else {
            throw ValidationError.dimensionsTooLarge
        }
        return source
    }

    /// Overflow-safe dimension check. `width * height` on a crafted IHDR can trap.
    static func isAllowedPixelSize(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0,
              width <= maxPixelDimension, height <= maxPixelDimension
        else { return false }
        let (pixelCount, overflow) = width.multipliedReportingOverflow(by: height)
        return !overflow && pixelCount <= maxPixelCount
    }

    /// Validates the PNG, then decodes it eagerly with its longest edge at most `maxPixelSize`
    /// so the full-resolution bitmap is never allocated. Smaller images are not upscaled.
    static func cgImage(fromPNG data: Data, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0, let source = try? validatedSource(data) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
