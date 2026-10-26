//
//  PageBlackout.swift
//  Remedy
//
//  blacks out personal info on the page picture before it can leave the phone
//

import Foundation
import UIKit

enum PageBlackout {

    // a copy of the picture with every piece that held a hidden word covered
    // plus barcodes since patient stickers carry the record number
    static func image(for page: ScannedPage, hiding hidden: [String]) -> UIImage? {
        guard let image = page.image else { return nil }
        let needles = hidden.map { $0.lowercased() }.filter { $0.count >= 3 }
        let covered = page.lines.filter { line in
            let text = line.text.lowercased()
            return needles.contains { text.contains($0) } || hasLongNumber(line.text)
                || PatientNames.contains(line.text, names: PatientNames.saved)
        }.map(\.box) + page.barcodes

        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            image.draw(at: .zero)
            UIColor.black.setFill()
            for box in covered {
                let rect = CGRect(x: box.minX * size.width, y: box.minY * size.height,
                                  width: box.width * size.width, height: box.height * size.height)
                context.fill(rect.insetBy(dx: -6, dy: -4))
            }
        }
    }

    // jpeg small enough to send
    static func jpeg(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1600 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: 0.7)
    }

    // record numbers the text rules also hide
    private static func hasLongNumber(_ text: String) -> Bool {
        text.range(of: "(?<![\\d(-])\\d{6,}(?![\\d)-])", options: .regularExpression) != nil
    }
}
