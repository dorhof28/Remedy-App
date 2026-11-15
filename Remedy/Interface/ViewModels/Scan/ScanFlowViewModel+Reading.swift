//
//  ScanFlowViewModel+Reading.swift
//  Remedy
//
//  scanned pages, reading and the problems that can stop it
//

import Foundation
import os
import PhotosUI
import SwiftUI
import UIKit

extension ScanFlowViewModel {

    // camera pages
    func process(images: [UIImage]) async {
        stage(images)
    }

    // photos picked from the library
    func processPhotos() async {
        var images: [UIImage] = []
        for item in photoItems {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        photoItems = []
        stage(images)
    }

    var pagesHint: String { "Make sure every page is sharp and nothing is cut off." }
    var scanMoreButton: String { "Scan More Pages" }
    var addElsewhereButton: String { "Add From Somewhere Else" }
    var addElsewhereDetail: String { "Photos, PDF, MyChart, Apple Health" }
    var pagesTitle: String { pendingImages.count == 1 ? "1 Page" : "\(pendingImages.count) Pages" }

    // new pictures join the pages, or replace the one being scanned again
    private func stage(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        if let page = rescanPage, page - 1 < pendingImages.count, let first = images.first {
            pendingImages[page - 1] = first
            rescanPage = nil
            Task { await readPages() }
            return
        }
        pendingImages += images
        showsSources = false
        Motion.run { step = .pages }
    }

    // the camera when there is one, else the photo library
    func scanMore() { intakeRequest = canUseCamera ? .camera : .photos }

    func addElsewhere() { begin() }

    // reads the checked pages on this iphone, one at a time so the screen can say which
    func readPages() async {
        start(pages: pendingImages.count)
        let run = readRun
        var scanned: [ScannedPage] = []
        for (index, image) in pendingImages.enumerated() {
            currentPage = index + 1
            scanned += await TextReader.scan([image], modelReader: pageReader)
            guard run == readRun else { return }
        }
        await read(scanned)
    }

    // stops reading and goes back to the pages, nothing was sent
    func cancelReading() {
        readRun += 1
        Motion.run { step = pendingImages.isEmpty ? (isAddingPapers ? .addPapers : .welcome) : .pages }
    }

    // what the reading screen says it is doing
    var readingHeadline: String {
        switch stage {
        case .readingWords where pageCount > 0:
            return "Reading page \(max(currentPage, 1)) of \(pageCount)\u{2026}"
        case .readingWords, .removingPersonalInfo:
            return "Reading your papers\u{2026}"
        default:
            return "Making your plan\u{2026}"
        }
    }

    var readingDetail: String {
        switch stage {
        case .readingWords, .removingPersonalInfo:
            return "Finding the text and hiding names on this iPhone. This takes about 20 seconds."
        default:
            return planner.sendsDataOffPhone
                ? "Only the text with names hidden was sent. This takes about a minute."
                : "Nothing leaves this iPhone. This can take a few minutes."
        }
    }

    // nil while the plan is being made, there is no page count to show then
    var readingProgress: Double? {
        guard stage == .readingWords, pageCount > 0 else { return nil }
        return Double(max(currentPage - 1, 0)) / Double(pageCount)
    }

    var hardPageTitle: String { "Page \(hardPage ?? 1) is hard to read" }
    var hardPageDetail: String { "Try again in brighter light, with the whole page flat and inside the frame." }
    var scanAgainButton: String { "Scan Page \(hardPage ?? 1) Again" }
    var skipPageButton: String { "Skip This Page" }
    var cloudTitle: String { "Can\u{2019}t reach Apple\u{2019}s cloud" }
    var cloudDetail: String { "Check that Wi-Fi or cellular data is on, then try again. Your pages are saved on this iPhone." }
    var tryAgainButton: String { "Try Again" }
    var keepOnPhoneButton: String { "Keep on This iPhone" }
    var readingNavTitle: String { "Reading Papers" }

    func scanHardPageAgain() {
        rescanPage = hardPage
        scanMore()
    }

    // goes on without the hard page, a to-do says it wasn't read
    func skipHardPage() async {
        guard let page = hardPage, page - 1 < pendingImages.count else { return }
        skippedPages.append(page)
        pendingImages.remove(at: page - 1)
        hardPage = nil
        await readPages()
    }

    // the to-do for each page that was left out
    var skippedPageTasks: [String] {
        skippedPages.map { "Page \($0) wasn\u{2019}t read. Ask your care team or scan it again." }
    }

    // sends the same pages again, to the same reader unless the patient picked the phone
    func readAgain(on reader: ModelChoice?) async {
        start(pages: lastScanned.count)
        await process(scanned: lastScanned, planner: reader)
    }

    func tryCloudAgain() async { await readAgain(on: plannerForThisRead) }

    // a PDF from the Files app
    func processPDF(at url: URL) async {
        start()
        do {
            await read(try await PDFReader.scan(url, modelReader: pageReader))
        } catch {
            errorText = (error as? PDFReaderError)?.errorDescription ?? "We couldn\u{2019}t open that PDF."
            Motion.run { step = .addPapers }
        }
    }

    // resets the read and saves the names to hide before reading starts
    func start(pages: Int = 0) {
        PatientNames.save(namesToHide)
        errorText = nil
        showsTryOnPhone = false
        stage = .readingWords
        pageCount = pages
        Motion.run { step = .reading }
    }

    // the words are read first, then the phone ai and the rules propose who gave it for the patient to confirm
    // this text is not hidden yet so only the phone ai ever sees it
    func read(_ scanned: [ScannedPage]) async {
        lastScanned = scanned
        // a page with no words gets its own screen, scan it again or skip it
        if let empty = scanned.firstIndex(where: { $0.text.trimmed.isEmpty }),
           !pendingImages.isEmpty {
            hardPage = empty + 1
            errorText = hardPageTitle
            showsTryOnPhone = false
            Motion.run { step = .addPapers }
            return
        }
        guard scanned.contains(where: { !$0.text.trimmed.isEmpty }) else {
            errorText = PlanReaderError.couldNotRead.errorDescription
            Motion.run { step = .addPapers }
            return
        }
        pageCount = scanned.count
        let pages = scanned.map { TypoFixer.fix($0.text) }
        var found: PaperGuess?
        if detailsFinder.isAvailable {
            do {
                found = try await detailsFinder.find(in: pages.joined(separator: "\n\n"))
            } catch {
                // only the kind of error since the message could hold page words
                PlanReaders.log.error("Phone AI could not read paper details: \(String(describing: type(of: error)))")
            }
        }
        proposal = PaperClues.merged(ai: found, rules: PaperClues.guess(from: pages), pages: pages)
        chosenSource = proposal.source
        chosenField = proposal.field
        showDoctorKind(for: proposal)
        doctorName = proposal.doctor
        hospitalText = proposal.hospital
        giver = nil
        hasPrintedDate = proposal.date != nil
        printedDate = proposal.date ?? AppClock.now()
        // fixed rules sort the papers, never the AI, and the patient can change what they decided
        let guess = PaperClues.kind(in: pages, usual: usualPaper)
        kindGuess = guess
        if paperChoice == .notSure { paper = guess.kind }
        detailsStep = detailsSteps.first ?? .who
        Motion.run { step = .paperDetails }
    }

    // fix typos and hide personal info on the phone then the patient always checks it
    func process(scanned: [ScannedPage], planner override: ModelChoice? = nil) async {
        lastScanned = scanned
        plannerForThisRead = override
        pageCount = scanned.count
        Motion.run { stage = .removingPersonalInfo }
        let fixed = scanned.map { TypoFixer.fix($0.text) }
        redactedPages = settings.redactBeforePlanning
            ? await AIRedactor.redact(fixed, finder: hidingFinder)     // on this iphone or apple private cloud plus rules, never another cloud
            : fixed.map { RedactedPage(original: $0) }
        Motion.run { step = .checkHidden }
    }
}
