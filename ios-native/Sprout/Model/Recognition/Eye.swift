import CoreVideo
import UIKit
import Vision

/// Что на снимке: классификатор Apple, прямо на телефоне и без сети. В
/// симуляторе не работает — это не поломка.
enum Eye {
    /// Не вышло — пустой ответ: подсказка необязательна.
    static func look(at image: UIImage) async -> [Sighting] {
        guard let frame = image.cgImage else { return [] }
        let request = ClassifyImageRequest()
        guard let seen = try? await request.perform(on: frame) else {
            return []
        }
        return seen.map {
            Sighting(name: $0.identifier, confidence: Double($0.confidence))
        }
    }

    static func guess(_ image: UIImage) async -> Guess? {
        Species.read(await look(at: image))
    }
}

extension Eye {
    /// Сторона уменьшенного снимка: разбору хватает, а Vision и цикл по
    /// пикселям укладываются в доли секунды.
    private static let side = 320

    /// Годится ли снимок для своей модели и какие на нём цвета. Маску
    /// растения даёт Vision; нет её — растение ищется в середине кадра.
    static func study(_ image: UIImage) async -> Sample.Reading {
        guard let frame = image.cgImage else {
            return Sample.Reading(verdict: .empty)
        }
        return await Task.detached(priority: .userInitiated) {
            guard let small = shrink(frame) else {
                return Sample.Reading(verdict: .empty)
            }
            let mask = subject(frame, width: small.width, height: small.height)
            return Sample.read(rgba: small.pixels, mask: mask,
                               width: small.width, height: small.height)
        }.value
    }

    /// Что видно на листьях — для диагностики, см. `Finding`. Та же маска
    /// растения, что и для своей модели.
    static func examine(_ image: UIImage) async -> Symptoms {
        guard let frame = upright(image) else { return Symptoms() }
        return await Task.detached(priority: .userInitiated) {
            guard let small = shrink(frame) else { return Symptoms() }
            let mask = subject(frame, width: small.width, height: small.height)
            return Symptoms.read(rgba: small.pixels, mask: mask,
                                 width: small.width, height: small.height)
        }.value
    }

    /// Снимок стоймя: у снимка с камеры `cgImage` лежит на боку, а
    /// диагностике важно, где верх растения, а где горшок. Заодно не больше
    /// двух сторон разбора — Vision хватает.
    private static func upright(_ image: UIImage) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let limit = CGFloat(side * 2)
        if image.imageOrientation == .up, longest <= limit {
            return image.cgImage
        }
        let scale = min(1, limit / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(),
                          height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .cgImage
    }

    /// Снимок в RGBA нужного размера.
    private static func shrink(_ frame: CGImage)
        -> (pixels: [UInt8], width: Int, height: Int)? {
        let scale = Double(side) / Double(max(frame.width, frame.height))
        let width = max(Int(Double(frame.width) * min(scale, 1)), 16)
        let height = max(Int(Double(frame.height) * min(scale, 1)), 16)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(frame, in: CGRect(x: 0, y: 0, width: width,
                                           height: height))
            return true
        }
        return drawn ? (pixels, width, height) : nil
    }

    /// Маска главного предмета снимка — Vision отделяет растение с горшком
    /// от фона. Байт на пиксель, в размере уменьшенного снимка.
    private static func subject(_ frame: CGImage, width: Int,
                                height: Int) -> [UInt8]? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: frame, options: [:])
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first,
              let buffer = try? result.generateScaledMaskForImage(
                  forInstances: result.allInstances, from: handler)
        else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let sourceWidth = CVPixelBufferGetWidth(buffer)
        let sourceHeight = CVPixelBufferGetHeight(buffer)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        let float = CVPixelBufferGetPixelFormatType(buffer)
            == kCVPixelFormatType_OneComponent32Float
        var mask = [UInt8](repeating: 0, count: width * height)
        for y in 0 ..< height {
            let sourceY = min(y * sourceHeight / height, sourceHeight - 1)
            let line = base.advanced(by: sourceY * row)
            for x in 0 ..< width {
                let sourceX = min(x * sourceWidth / width, sourceWidth - 1)
                let value: Float = float
                    ? line.assumingMemoryBound(to: Float.self)[sourceX]
                    : Float(line.assumingMemoryBound(to: UInt8.self)[sourceX])
                        / 255
                mask[y * width + x] = UInt8(min(max(value, 0), 1) * 255)
            }
        }
        return mask
    }
}
