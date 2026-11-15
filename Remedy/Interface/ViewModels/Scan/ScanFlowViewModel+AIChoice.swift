//
//  ScanFlowViewModel+AIChoice.swift
//  Remedy
//
//  which ai, what gets sent, and the read itself
//

import Foundation
import os
import UIKit

extension ScanFlowViewModel {

    // true when hiding is off and the planner sends data off the phone
    var needsRedactionWarning: Bool { settings.needsRedactionWarning }

    // the ai that hides names, fixed rules when the patient picked them
    var hidingFinder: PersonalInfoFinder {
        if settings.redactionChoice == .rulesOnly { return RulesOnlyFinder() }
        return finder ?? PersonalInfoFinders.finder(for: settings.redactionChoice)
    }

    // the ai that reads the page next to the camera, nil when the camera reads alone
    var pageReader: PageModelReader? { PageModelReader.reader(for: settings.readingChoice) }

    // what stops the picked models from being used right now
    var aiProblem: AIProblem? {
        settings.problem(phoneAIReady: hidingFinder.isAvailable, pageReaderReady: PageModelReader.isReady(settings.readingChoice),
                         readerReady: readerFor(planner).isAvailable)
    }

    // the patient changed the choice so the saved one is used
    func reloadAIChoice() {
        aiChoiceVersion += 1
        settings = ModelSettings.load(from: defaults)
    }

    var tryOnPhoneButton: String { "Try On this iPhone instead?" }

    // the patient tapped the button so this one read uses the phone
    func tryOnPhone() async { await readAgain(on: .onPhone) }

    // said plainly when the phone ai did not check every page
    var rulesOnlyNote: String? {
        guard settings.redactBeforePlanning else { return nil }
        let unchecked = redactedPages.indices.filter { !redactedPages[$0].usedAI }
        if unchecked.isEmpty { return nil }
        if unchecked.count == redactedPages.count, settings.redactionChoice == .rulesOnly {
            return "You chose built-in checks only to hide your details. They can miss some, so check the page closely."
        }
        if unchecked.count == redactedPages.count {
            return "\(settings.redactionChoice.title) wasn\u{2019}t ready, so only built-in checks hid your details. They can miss some, so check the page closely."
        }
        let pages = PlainText.list(unchecked.map { "\($0 + 1)" })
        return "The AI couldn\u{2019}t check page \(pages), so only built-in checks hid details there. Check it closely."
    }

    // a tap shows a hidden part or hides a word, on every page
    func tapPiece(_ index: Int, onPage page: Int) {
        guard redactedPages.indices.contains(page) else { return }
        let pieces = redactedPages[page].pieces
        guard pieces.indices.contains(index) else { return }
        let piece = pieces[index]
        guard piece.isHidden || piece.isWord else { return }
        for i in redactedPages.indices {
            if piece.isHidden {
                redactedPages[i].show(piece.text)
            } else {
                redactedPages[i].hide(piece.text, keepingMedicines: false)
            }
        }
    }

    // the sheet's "Send" is remembered for this choice
    func confirmSend() async {
        sheetShownFor = sheetShownFor.union([planner.id.rawValue])
        await sendNow()
    }

    // the sheet's other button reads this one paper on the phone, nothing leaves it
    func useOnPhoneInstead() async {
        plannerForThisRead = .onPhone
        await sendNow()
    }

    // the patient said yes on the send sheet
    private func sendNow() async {
        showsSendSheet = false
        Motion.run { step = .reading }
        await send()
    }

    static let sheetShownKey = "sendSheetShownFor"

    // choices where the patient already saw the sheet
    var sheetShownFor: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.sheetShownKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: Self.sheetShownKey) }
    }

    var sendsPhoto: Bool { settings.attachesPhoto(for: planner) }

    // where the page goes, said at the top of the check and the sheet
    var destination: PrivacyPlace { .of(planner) }
    var destinationText: String {
        switch destination {
        case .thisPhone: return "Staying on this iPhone"
        case .homeNetwork: return "Going to your Mac"
        case .appleCloud: return "Going to Apple Private Cloud"
        case .online: return "Going to \(planner.displayName)"
        }
    }

    var consentTitle: String { "What the AI Will See" }
    var hiddenRowTitle: String { "Hidden on this iPhone" }
    var hiddenRowDetail: String { "Name, birth date, record numbers, address, phone" }
    var whereRowTitle: String { "Where it goes" }
    var consentFootnote: String { "Nothing has been sent yet. Remedy asks again for each new paper." }
    var keepOnPhoneTitle: String { keepOnPhoneButton }

    // where the page goes and what happens to it there
    var whereRowDetail: String {
        switch destination {
        case .thisPhone: return "This iPhone. Nothing leaves it."
        case .homeNetwork: return "Your Mac, on your own Wi-Fi."
        case .appleCloud: return "Apple Private Cloud Compute. It is used to read this page and is not kept or used for training."
        case .online: return "\(planner.displayName), over the internet."
        }
    }

    // keep on this iphone only means something when the page would leave it
    var offersKeepOnPhone: Bool { destination != .thisPhone }

    // send means the patient said yes for this paper, the same as on the sheet
    func sendFromConsent() async { await confirmSend() }

    var sheetTitle: String { "What gets sent" }
    var sheetPhotoTitle: String { "The photo, blacked out on this phone" }
    var sheetPhoneButton: String { "Use On this iPhone instead" }
    var sheetSendButton: String { "Send" }
    var sheetNotHiddenWarning: String { "Hiding names and addresses is turned off in Settings, so they may be sent." }

    var sheetDetail: String {
        "\(planner.displayName) gets the text you just checked" + (sendsPhoto ? " and the photo below. " : ". ")
            + "Black parts never leave your phone."
    }

    // the page photos with the hidden words covered
    private func blackedOutPictures() -> [UIImage?] {
        zip(lastScanned, redactedPages).map { scanned, page in
            settings.redactBeforePlanning || !page.hidden.isEmpty ? PageBlackout.image(for: scanned, hiding: page.hidden) : scanned.image
        }
    }

    // blacks out the picture with the same words then asks the picked AI
    private func send() async {
        let texts = redactedPages.map(\.text)
        let pictures = blackedOutPictures()

        // the picked ai gets the text plus the photo unless it is text only
        let choice = planner
        let jpegs = pictures.map { settings.attachesPhoto(for: choice) ? $0.flatMap(PageBlackout.jpeg) : nil }

        Motion.run { stage = .modelReading }
        let reader = readerFor(choice)
        let run = readRun
        do {
            var read = try await reader.readPlan(from: texts, pictures: jpegs, paper: paper)
            guard run == readRun else { return }
            read.readBy = reader.name
            PlanReaders.log.info("Read the papers with \(reader.name)")
            stampPaper(on: &read)
            if let record = recordDraft {
                read = read.addingRecord(record)
                recordDraft = nil
            }
            Motion.run { stage = .done }
            checkItems(of: read)
        } catch {
            PlanReaders.log.error("\(reader.name) failed: \(error.localizedDescription)")
            // our own errors have patient-friendly words
            if let known = error as? PlanReaderError {
                errorText = known.errorDescription
            } else if error is URLError {
                errorText = "\(reader.name) could not be reached. Check your internet and try again."
            } else {
                errorText = "\(reader.name) could not read the page. You can try again or use another reader."
            }
            showsTryOnPhone = choice.id != .onPhone
            hardPage = nil
            Motion.run { step = .addPapers }
        }
    }
}
