//
//  ScanFlowViewModel+Demo.swift
//  Remedy
//
//  debug and demo only helpers
//

import Foundation
import UIKit

extension ScanFlowViewModel {

    // DEMO ONLY skips the camera and uses the sample page text, debug builds only
    func useSamplePapers() async {
        #if DEBUG
        start()
        try? await Task.sleep(for: .seconds(1))
        await read([ScannedPage(text: SampleDrafts.pageText(for: paper))])
        #endif
    }

    // DEBUG ONLY the screenshot launch option opens the setup steps from the welcome screen
    func openDemoScreen() async -> String? {
        guard let screen = LaunchOptions.demoScreen else { return nil }
        switch screen {
        case "setup":
            await setup.load()
            if setup.hasSteps { step = .setup }
        case "reader": showsAIChoice = true
        case "pages":
            pendingImages = (1...3).map { Self.samplePageImage(page: $0) }
            step = .pages
        case "hardPage":
            pendingImages = (1...3).map { Self.samplePageImage(page: $0) }
            hardPage = 2
            errorText = hardPageTitle
            step = .addPapers
        case "cloud":
            errorText = cloudTitle
            showsTryOnPhone = true
            step = .addPapers
        case "importPick":
            var found = SampleFHIR.draft(paper: paper, now: AppClock.now())
            found.hospitalName = "Lakeside Health"
            offerImport(found, papers: SampleFHIR.papers(now: AppClock.now()), from: .myChart)
        default: break
        }
        return screen
    }

    // DEBUG ONLY a blank page that says SAMPLE for the screenshot screens
    private static func samplePageImage(page: Int) -> UIImage {
        let size = CGSize(width: 850, height: 1100)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let words = "SAMPLE\nDischarge papers\nPage \(page)" as NSString
            words.draw(at: CGPoint(x: 80, y: 120), withAttributes: [.font: UIFont.systemFont(ofSize: 64, weight: .bold),
                                                                   .foregroundColor: UIColor.darkGray])
        }
    }
}
