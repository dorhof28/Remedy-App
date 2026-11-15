//
//  PageModelReader.swift
//  Remedy
//
//  an ai that looks at the page photo and writes out every word, on this iphone or apple private cloud
//  the camera reading still runs next to it, and any number the two read differently is shown to the patient
//

import Foundation
import FoundationModels
import UIKit

// writes out every word on a page photo with a vision model
struct PageModelReader {
    let name: String
    let makeModel: () throws -> any LanguageModel
    // glm ocr is trained on one short prompt, the others get full instructions
    let prompt: String

    static let fullPrompt = """
        Write out every word on this page exactly as printed, top to bottom, in Markdown.
        Keep each bullet or numbered item on its own line starting with "- " or its number, \
        and join a line that wraps inside an item back onto that item. Keep tables as Markdown tables. \
        Read two columns one after the other. Copy numbers, doses and dates exactly. \
        Do not explain, summarize, fix or add anything.
        """

    // the reader for what the patient picked, nil for the camera alone
    static func reader(for choice: ReadingChoice) -> PageModelReader? {
        switch choice {
        case .camera:
            return nil
        case .privateCloud:
            return PageModelReader(name: choice.title, makeModel: {
                guard AppleAI.isCloudAvailable else { throw PlanReaderError.notReady(choice.title) }
                return PrivateCloudComputeLanguageModel()
            }, prompt: fullPrompt)
        case .glmOCR, .gemma, .gemmaLarge:
            guard let local = choice.localModel else { return nil }
            return PageModelReader(name: local.displayName, makeModel: { try LocalModelStore.shared.languageModel(local) },
                                   prompt: local == .glmOCR ? "Text Recognition:" : fullPrompt)
        }
    }

    // ready when downloaded and this phone can run it
    static func isReady(_ choice: ReadingChoice) -> Bool {
        switch choice {
        case .camera: return true
        case .privateCloud: return AppleAI.isCloudAvailable
        default: return choice.localModel.map { LocalModelStore.shared.isReady($0) } ?? false
        }
    }

    // the page as plain text in the same shape the camera reader gives
    func transcribe(_ image: UIImage) async throws -> String {
        let session = LanguageModelSession(model: try makeModel())
        // the model shrinks the page to about 1000 pixels anyway, a full camera photo only wastes memory
        let page = Self.shrunk(image, longSide: 1600)
        let response = try await session.respond(to: Prompt {
            prompt
            Attachment(page)
        }, options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 3500))
        return MarkdownText.plain(response.content)
    }

    // the photo scaled down so its long side is at most this many pixels
    static func shrunk(_ image: UIImage, longSide: CGFloat) -> UIImage {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let largest = max(pixels.width, pixels.height)
        guard largest > longSide else { return image }
        let factor = longSide / largest
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: (pixels.width * factor).rounded(), height: (pixels.height * factor).rounded())
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
