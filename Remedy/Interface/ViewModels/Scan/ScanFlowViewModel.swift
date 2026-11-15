//
//  ScanFlowViewModel.swift
//  Remedy
//
//  welcome scan and confirm for both looks, the state lives here and each part is an extension
//

import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

// the whole flow from papers to a saved plan, one step at a time
@Observable
final class ScanFlowViewModel {

    // MARK: - State
    var step: ScanStep
    var paper: PaperKind = .beforeSurgery
    var stage: ReadingStage = .readingWords
    var pageCount = 0               // pages being read
    var draft: DraftPlan?
    var cardIndex = 0
    var removedIDs: Set<UUID> = []  // "Not on my papers"
    var surgeryDate: Date
    var errorText: String?
    var isImportingFromEpic = false
    var isImportingFromHealth = false
    var photoItems: [PhotosPickerItem] = []
    var chosenSource: PaperSource?  // who gave the paper, nil is left blank
    var chosenField: PaperField?    // only for another doctor
    var giver: NewerPaperRule.Giver?  // who gave it, screen 85, nil until picked
    var hospitalText = ""           // the From row, read from the page and fixable
    var doctorName = ""
    var printedDate: Date
    var hasPrintedDate = false      // false is "No date on it"
    var detailsStep = PaperDetailsStep.who   // the simple look asks one question at a time
    var showsSources = false        // the sources sheet on the welcome screen
    var asksPaperKind = false       // the sheet's second part, before or after surgery
    var intakeRequest: PaperIntake? // set once everything is picked, the screen starts the camera, picker or import
    var paperChoice: PaperChoice?   // nil for imports, which never ask
    var kindGuess: PaperKindGuess?   // what the rules said about before or after
    var doctorKind: DoctorKind?
    var isPickingDoctorKind = false // the list of doctor kinds is open
    var otherKindText = ""          // only used when the kind is Other
    var gapPhone = ""               // a doctor phone the patient adds from the results
    var phoneGap = PhoneGapState.notAsked  // the missing phone asked first in the check, 87
    var proposal = PaperGuess()    // what the paper said, shown for the patient to confirm
    var namesToHide = PatientNames.savedText     // names saved in Settings, hidden along with the ones the phone finds
    var intake: PaperIntake?        // where the papers come from
    var settings = ModelSettings.load()          // which ai reads and whether to hide details first
    var showsTryOnPhone = false     // the picked ai failed so offer the phone, never switch by itself
    var plannerForThisRead: ModelChoice?   // only set by "Try On this iPhone instead?"
    var planner: ModelChoice { plannerForThisRead ?? settings.plannerChoice }

    // pages scanned, read and the problems on the way
    var pendingImages: [UIImage] = []   // pages waiting to be read, checked first
    var rescanPage: Int?                // a hard page being scanned again, 1 based
    var skippedPages: [Int] = []        // pages left out, each becomes a to-do
    var readRun = 0                     // cancel bumps it so a late result is dropped
    var currentPage = 0                 // the page being read now, 1 based
    var hardPage: Int?                  // a page with no words found, 1 based

    // what a mychart or health import found
    var importSource: ImportSource = .myChart
    var importRows: [ImportRow] = []
    var importPapers: [RecordPaper] = []
    var pickedImports: Set<String> = []
    // record items held while picked visit papers are read, added to what the ai reads
    var recordDraft: DraftPlan?

    // the ai choice and what gets sent
    var aiChoiceVersion = 0         // bumped so the two plain lines reload
    var showsAIChoice = false       // the sheet that asks which models to use
    var redactedPages: [RedactedPage] = []  // every page with its hidden parts changed by taps on the check screen
    var showsSendSheet = false
    var previewPictures: [UIImage] = []     // the blacked out photos the sheet shows

    // finishing
    var hasPickedDate = false       // true once a date came from the papers or the patient picked one
    var whatChanged: WhatChangedViewModel?    // what the saved paper changed, nil when nothing to show
    var didSave = false
    let setup: OnboardingViewModel  // the lock calendar and reminder questions, first plan only
    // true when adding papers to a plan that already exists
    let isAddingPapers: Bool
    let planHasSurgeryDate: Bool
    let readerFor: (ModelChoice) -> PlanReader
    let defaults: UserDefaults
    let finder: PersonalInfoFinder?       // tests pass a fake, the app uses the patient's pick
    let detailsFinder: PaperDetailsFinder
    var lastScanned: [ScannedPage] = []    // kept for "Try On this iPhone instead?"

    init(isAddingPapers: Bool = false, planHasSurgeryDate: Bool = false, now: Date = AppClock.now(),
         finder: PersonalInfoFinder? = nil,
         detailsFinder: PaperDetailsFinder = PhonePaperDetailsFinder(),
         defaults: UserDefaults = .standard,
         readerFor: @escaping (ModelChoice) -> PlanReader = { PlanReaders.reader(for: $0) }) {
        self.defaults = defaults
        self.setup = OnboardingViewModel(defaults: defaults, asksProfile: !isAddingPapers)
        self.isAddingPapers = isAddingPapers
        self.planHasSurgeryDate = planHasSurgeryDate
        self.finder = finder
        self.detailsFinder = detailsFinder
        self.readerFor = readerFor
        self.step = isAddingPapers ? .addPapers : .welcome
        self.surgeryDate = now
        self.printedDate = now
        // after surgery is the usual second scan
        self.paper = isAddingPapers ? .afterSurgery : .beforeSurgery
    }
}
