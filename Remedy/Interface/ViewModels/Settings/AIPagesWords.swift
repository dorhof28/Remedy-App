//
//  AIPagesWords.swift
//  Remedy
//
//  words for how papers are read (64), making the plan (65), reading the page (105),
//  your own ai key (106), add a key (107) and turning off name hiding (108)
//

import Foundation

// the words on the reader and key pages in settings
enum AIPagesWords {

    // 64
    static let readingStep = "1. Reading the page"
    static let hidingStep = "2. Hiding names"
    static let planStep = "3. Making the plan"
    static let hidingOn = "On \u{00B7} runs on this iPhone"
    static let hidingOff = "Off"
    static let stepsFooter = "Nothing leaves the phone before \u{201C}What the AI will see\u{201D}. Step 1 sends anything only if you pick an AI to read the photos."

    // 65
    static let planTitle = "Making the Plan"
    static let onPhoneHeader = "On this iPhone"
    static let cloudHeader = "Cloud"
    static let macHeader = "My Mac"
    static let appleIntelligence = "Apple Intelligence"
    static let appleIntelligenceText = "Built in \u{00B7} nothing to download"
    static let moreModels = "Get More Models"
    static let privateCloud = "Apple Private Cloud Compute"
    static let privateCloudText = "Fastest \u{00B7} asks before each paper"
    static let ownKey = "Use Your Own AI Key"
    static let ownKeyText = "Claude, Gemini, OpenAI and more"
    static let connectMac = "Connect a Mac"
    static let connectMacText = "LM Studio, oMLX or Ollama on the same Wi-Fi"
    static let useMac = "Use My Mac"
    static let planFooter = "Whatever you pick, you still check every medicine and rule before it goes in your plan."
    static let keySavedChoice = "Your own key"

    // 105
    static let readingTitle = "Reading the Page"
    static let cameraText = "iPhone camera text"
    static let cameraDetail = "On this iPhone \u{00B7} recommended"
    static let readingFooter = "iPhone camera text sends nothing: only the text it finds goes on, with names hidden. An AI reading the photo gets the picture of each page, and it still goes through \u{201C}What the AI will see\u{201D} first."

    static func readsPhoto(_ name: String) -> String { "\(name) reads the photo" }
    static func usesKey(_ name: String) -> String { "Uses your \(name) key" }
    static func addKeyFirst(_ name: String) -> String { "Add a \(name) key first" }

    // 106
    static let keysTitle = "Your Own AI Key"
    static let keySaved = "Key saved"
    static let noKey = "No key"
    static let customAddress = "Your own address"
    static let keysFooter = "Keys stay in this iPhone\u{2019}s Keychain. Your papers go to the company you pick, under its rules, only after \u{201C}What the AI will see\u{201D}. If it fails, Remedy never switches to another AI on its own."

    // 107
    static let keyLabel = "Key"
    static let keyPrompt = "Paste your key"
    static let modelLabel = "Model"
    static let pickModel = "Pick a model"
    static let addressLabel = "Address"
    static let saveKey = "Save Key"
    static let checkKey = "Check Key"
    static let removeKey = "Remove Key"
    static let removeAsk = "Remove this key?"
    static let checking = "Checking your key\u{2026}"
    static let keyWorks = "Key works"
    static func keyWorksText(_ seconds: Int) -> String { "Test page read in \(seconds) second\(seconds == 1 ? "" : "s")" }
    static let refused = "The company didn\u{2019}t accept this key. Check it and try again."
    static let offline = "No internet. Try again when you\u{2019}re online."
    static let freeFooter = "On a free key, this company may use what it gets to improve its AI."
    static let freeToggle = "This is a free key"

    // the patient says whether the key is free, nothing can tell from the key itself
    static func freeKey(_ choice: ModelChoice) -> String { "freeKey.\(choice.id.rawValue)" }
    static func isFree(_ choice: ModelChoice) -> Bool { UserDefaults.standard.bool(forKey: freeKey(choice)) }

    // 68 and 108
    static let hideToggle = "Hide names before reading"
    static let hideFooter = "Recommended. Apple\u{2019}s on-device reading always hides names."
    static let namesHeader = "Names"
    static let hideOffTitle = "Turn off name hiding?"
    static let hideOffMessage = "Your name, birth date and record numbers would go to the cloud AI you picked. Apple\u{2019}s on-device reading still hides them."
    static let turnOff = "Turn Off"
    static let keepOn = "Keep On"

    // the fake page a key is checked with, never patient data
    static let samplePage = "SAMPLE discharge instructions. Acetaminophen 500 mg tab: take 2 tabs PO q8h x 14 days for pain."

    // the key providers in the order of 106
    static let keyProviders: [ModelChoice.ID] = [.claude, .gemini, .openAI, .openRouter, .groq, .mistral, .openAICompatible]
}

// the result of Check Key
enum KeyCheck: Equatable {
    case idle
    case checking
    case works(seconds: Int)
    case refused
    case offline

    // an error from testing a key as plain words
    static func from(_ error: Error) -> KeyCheck {
        if let url = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost].contains(url.code) {
            return .offline
        }
        return .refused
    }
}
