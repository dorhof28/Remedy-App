//
//  PagePreparer.swift
//  Remedy
//
//  gets a photo of a paper ready to read: cut the page off the table, square it up and even out shadows
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Vision
import os

// cuts the page off the table, squares it up and evens out shadows
enum PagePreparer {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static let log = Logger(subsystem: "Remedy", category: "Reading")

    // the page cut out of the photo and squared up, or the photo as it was when no clear page is found
    // scans from the document camera are already flat so they come back the same
    static func flattened(_ image: CGImage) async -> CGImage {
        guard let found = try? await DetectDocumentSegmentationRequest().perform(on: image),
              found.confidence > 0.5 else { return image }
        let size = CGSize(width: image.width, height: image.height)
        let corners = [found.topLeft, found.topRight, found.bottomRight, found.bottomLeft]
            .map { $0.toImageCoordinates(size, origin: .lowerLeft) }
        let area = quadArea(corners) / (size.width * size.height)
        // too small is probably a sticker, nearly all of it means the page already fills the photo
        guard area > 0.25, area < 0.94 else { return image }
        // a sheet of paper is about 1.3 to 1.4 times as long as it is wide, a strip or a square is a wrong find
        let width = (hypot(corners[1].x - corners[0].x, corners[1].y - corners[0].y)
                     + hypot(corners[2].x - corners[3].x, corners[2].y - corners[3].y)) / 2
        let height = (hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y)
                      + hypot(corners[2].x - corners[1].x, corners[2].y - corners[1].y)) / 2
        let shape = max(width, height) / max(min(width, height), 1)
        guard shape > 1.15, shape < 1.75 else { return image }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = CIImage(cgImage: image)
        filter.topLeft = corners[0]
        filter.topRight = corners[1]
        filter.bottomRight = corners[2]
        filter.bottomLeft = corners[3]
        guard let output = filter.outputImage, let flat = context.createCGImage(output, from: output.extent) else { return image }
        log.info("Page cut out of the photo (\(Int(area * 100))% of it)")
        return flat
    }

    // grey page with the shadows lifted, same size so every box still lines up with the photo
    // the text is taken out with a max filter to find the light on the paper, then the page is divided by it
    static func evenLight(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        let grey = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        let scale = max(CGFloat(image.width), CGFloat(image.height)) / 1200
        let paper = grey
            .applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: max(4, 8 * scale)])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 20 * scale])
            .cropped(to: input.extent)
        let even = paper.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: grey])
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.35, kCIInputBrightnessKey: 0.02])
            .cropped(to: input.extent)
        return context.createCGImage(even, from: input.extent)
    }

    // area of the found page shape, a small one is not the page
    private static func quadArea(_ points: [CGPoint]) -> CGFloat {
        var sum: CGFloat = 0
        for index in points.indices {
            let a = points[index], b = points[(index + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }
}
