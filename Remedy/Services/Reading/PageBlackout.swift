//
//  PageBlackout.swift
//  Remedy
//
//  blacks out personal info on the page picture before it can leave the phone
//

import Foundation
import UIKit

// covers hidden words and barcodes on the page picture
enum PageBlackout {

    // a copy of the picture with every hidden word covered
    // plus barcodes since patient stickers carry the record number
    static func image(for page: ScannedPage, hiding hidden: [String]) -> UIImage? {
        guard let image = page.image else { return nil }
        let needles = needles(from: hidden)
        let nameWords = PatientNames.words(PatientNames.saved)
        let covered = page.lines.flatMap { boxes(in: $0, needles: needles, nameWords: nameWords) } + page.barcodes

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
                context.fill(rect.insetBy(dx: -4, dy: -4))
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

    // every hidden thing plus each of its words in case the camera split it up
    static func needles(from hidden: [String]) -> [String] {
        let words = hidden.flatMap { item in
            item.split { !$0.isLetter && $0 != "'" && $0 != "-" }.map(String.init)
        }.filter { $0.count >= 3 && !MedicalWords.isProtected($0) }
        return Array(Set((hidden + words).filter { $0.count >= 3 }))
    }

    // only the parts of a line that hold hidden words not the whole line
    // so a medicine next to a name stays readable
    static func boxes(in line: ScannedLine, needles: [String], nameWords: [String]) -> [CGRect] {
        let text = line.text as NSString
        var ranges: [NSRange] = []
        for needle in needles {
            ranges += matches("(?i)(?<![A-Za-z0-9])\(NSRegularExpression.escapedPattern(for: needle))(?![A-Za-z0-9])", in: line.text)
        }
        ranges += matches("(?<![\\d(-])\\d{6,}(?![\\d)-])", in: line.text)
        for range in matches("[A-Za-z'\u{2019}-]+", in: line.text) where PatientNames.isNameWord(text.substring(with: range), nameWords) {
            ranges.append(range)
        }

        // vision gives one box per piece so each letter gets an even share of its width
        // with a letter and a half extra on each side in case the letters are wider
        let letter = line.box.width / CGFloat(max(text.length, 1))
        return ranges.map { range in
            CGRect(x: line.box.minX + CGFloat(range.location) * letter - letter * 1.5,
                   y: line.box.minY,
                   width: CGFloat(range.length) * letter + letter * 3,
                   height: line.box.height)
        }
    }

    private static func matches(_ pattern: String, in text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }
}
