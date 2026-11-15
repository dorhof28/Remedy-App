//
//  ScanFlowViewModel+Choose.swift
//  Remedy
//
//  welcome words, where the papers come from and who gave them
//

import Foundation

extension ScanFlowViewModel {

    var appName: String { "Remedy" }
    var welcomeDetail: String { "Turns your hospital papers into a plan for each day." }
    var welcomeButton: String { "Get Started" }
    var demoButton: String { "Try Demo Mode" }
    var restoreButton: String { "Restore Backup" }
    var disclaimer: String { "Remedy helps you read your papers. It doesn\u{2019}t replace your doctor." }
    var choosePaperTitle: String { "Which papers?" }
    var sortPapersTitle: String { "Not sure, let Remedy sort it" }
    var sortPapersDetail: String { "Remedy reads the page and tells you what it decided" }
    var kindQuestionTitle: String { "Before or after surgery?" }
    var chooseSourceTitle: String { "Where are your papers?" }
    var cameraButton: String { "Scan With Camera" }
    var photosButton: String { "Choose Photos" }
    var pdfButton: String { "Choose a PDF" }
    var epicButton: String { "Import From MyChart" }
    var epicSource: String { "From MyChart (Epic)" }
    var healthButton: String { "Import From Apple Health" }
    var healthSource: String { "From Apple Health Records" }
    var sampleButton: String { "Use sample papers" }
    var namesHiddenNote: String { "Your name is hidden on this iPhone before anything is read." }
    var addPapersTitle: String { chooseSourceTitle }

    // one line on the welcome screen
    struct Feature: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    var features: [Feature] { [
        Feature(id: "scan", symbol: "camera", title: "Scan your papers", detail: "Take a picture of each page"),
        Feature(id: "check", symbol: "checkmark.circle", title: "Check every medicine", detail: "Nothing goes in your plan until you say it\u{2019}s right"),
        Feature(id: "today", symbol: "sun.max", title: "See what to do today", detail: "Doses, to-dos and who to call"),
    ] }

    // MARK: - Choose papers

    // before or after surgery papers
    struct PaperOption: Identifiable {
        let id: PaperKind
        let title: String
        let detail: String
        let symbol: String
    }

    var paperOptions: [PaperOption] { [
        PaperOption(id: .beforeSurgery, title: beforeSurgeryTitle, detail: "Getting ready for the operation", symbol: "calendar.badge.clock"),
        PaperOption(id: .afterSurgery, title: afterSurgeryTitle, detail: "Going home and getting better", symbol: "house"),
    ] }

    // the paper kind most papers are when the page does not say
    var usualPaper: PaperKind { isAddingPapers ? .afterSurgery : .beforeSurgery }

    var canUseCamera: Bool { DocumentScanner.isAvailable }

    // DEMO ONLY the sample-papers button shows in debug builds started as a demo
    var showsSampleButton: Bool {
        #if DEBUG
        return LaunchOptions.isDemo
        #else
        return false
        #endif
    }

    // one way of getting the papers in
    struct IntakeOption: Identifiable {
        let id: PaperIntake
        let title: String
        let symbol: String
        var detail = ""
    }

    // the places papers can come from, only the ones that work on this phone
    var intakeOptions: [IntakeOption] {
        var options: [IntakeOption] = []
        if canUseCamera { options.append(IntakeOption(id: .camera, title: cameraButton, symbol: "camera")) }
        options.append(IntakeOption(id: .photos, title: photosButton, symbol: "camera"))
        options.append(IntakeOption(id: .pdf, title: pdfButton, symbol: "doc.text"))
        if showsEpicButton { options.append(IntakeOption(id: .myChart, title: epicButton, symbol: "doc.text")) }
        if showsHealthButton { options.append(IntakeOption(id: .health, title: healthButton, symbol: "heart", detail: "Hospital medicines from your Health records")) }
        if showsSampleButton { options.append(IntakeOption(id: .sample, title: sampleButton, symbol: "doc.text", detail: "Fake papers for a demo")) }
        return options
    }

    // first pick: where the papers come from, MyChart and Health never ask before or after
    func chooseIntake(_ source: PaperIntake) {
        intake = source
        errorText = nil
        paperChoice = nil
        switch source {
        case .myChart, .health: startIntake(source)
        // no before or after question, the rules read it from the page and each line's own day
        case .camera, .photos, .pdf, .sample: chooseKind(.notSure)
        }
    }

    // second pick: before, after, or let the rules sort it
    func chooseKind(_ choice: PaperChoice) {
        paperChoice = choice
        switch choice {
        case .before: paper = .beforeSurgery
        case .after: paper = .afterSurgery
        case .notSure: paper = usualPaper
        }
        startIntake(intake ?? .photos)
    }

    // closes the sheet then starts, so the camera never opens over a closing sheet
    func startIntake(_ source: PaperIntake) {
        let wait = showsSources
        Motion.run {
            showsSources = false
            asksPaperKind = false
        }
        Task { @MainActor in
            if wait { try? await Task.sleep(for: .milliseconds(450)) }
            intakeRequest = source
        }
    }

    // "Add my papers" on the welcome screen opens the sources on the same screen
    func begin() {
        asksPaperKind = false
        showsSources = true
    }

    // MARK: - Who gave the paper

    // one of the big choices
    func chooseSource(_ source: PaperSource) {
        Motion.run {
            chosenSource = source
            if source == .specialist {
                isPickingDoctorKind = true
            } else {
                chosenField = nil
                doctorKind = nil
                isPickingDoctorKind = false
            }
        }
    }

    // the kind to show picked for what the paper said
    func showDoctorKind(for guess: PaperGuess) {
        let isSpecialist = guess.source == .specialist
        isPickingDoctorKind = isSpecialist
        doctorKind = isSpecialist && guess.field != nil ? DoctorKind.kind(source: guess.source, field: guess.field) : nil
        otherKindText = ""
    }

    // a value counts as found on the paper only while it still matches what the paper said
    var sourceWasFound: Bool { proposal.source != nil && chosenSource == proposal.source && chosenField == proposal.field }
    var dateWasFound: Bool {
        guard let found = proposal.date, hasPrintedDate else { return false }
        return DayMath.calendar.isDate(found, inSameDayAs: printedDate)
    }

    // goes back one step in this part of the flow
    func goBack() {
        Motion.run {
            switch step {
            case .welcome:
                asksPaperKind = false
            case .addPapers:
                if asksPaperKind { asksPaperKind = false } else if !isAddingPapers { step = .welcome }
            case .paperDetails:
                if let at = detailsSteps.firstIndex(of: detailsStep), at > 0 { detailsStep = detailsSteps[at - 1] } else { step = .addPapers }
            default: break
            }
        }
    }

    // MARK: - Choice lists as option cards

    var intakeItems: [OptionItem] {
        intakeOptions.map { OptionItem(id: $0.id.rawValue, symbol: $0.symbol, title: $0.title, subtitle: $0.detail) }
    }

    var paperItems: [OptionItem] {
        paperOptions.map { OptionItem(id: $0.id.rawValue, symbol: $0.symbol, title: $0.title, subtitle: $0.detail,
                                      isSelected: paper == $0.id) }
    }

    // the four givers of screen 85
    var sourceItems: [OptionItem] {
        NewerPaperRule.Giver.allCases.map { OptionItem(id: $0.rawValue, symbol: "doc.text", title: $0.title,
                                                       isSelected: shownGiver == $0) }
    }

    func pickPaper(_ id: String) {
        if let kind = PaperKind(rawValue: id) { Motion.run { paper = kind } }
    }

    // a giver from rule 6 or a paper source, both are on the same list
    func pickSource(_ id: String) {
        if let giver = NewerPaperRule.Giver(rawValue: id) { pickGiver(giver); return }
        if let source = PaperSource(rawValue: id) { chooseSource(source) }
    }
}
