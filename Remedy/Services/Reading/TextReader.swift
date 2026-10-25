//
//  TextReader.swift
//  Remedy
//
//  reads the words on a scanned page with vision
//

import Foundation
import UIKit
import Vision

enum TextReader {

    // one string per page lines in reading order
    static func read(_ images: [UIImage]) async -> [String] {
        var pages: [String] = []
        for image in images {
            pages.append(await read(image))
        }
        return pages
    }

    static func read(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true      // fixes "lbuprofen" -> "Ibuprofen"
        do {
            let observations = try await request.perform(on: cgImage)
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        } catch {
            print("Remedy: could not read page: \(error)")
            return ""
        }
    }
}
