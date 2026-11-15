//
//  Speaker.swift
//  Remedy
//
//  reads text out loud
//

import AVFoundation
import Observation

// reads screen text out loud
enum Speaker {

    // the read to me buttons watch this to show play or stop
    static let state = SpeakerState()

    // says the text, or stops when it is already talking
    static func toggle(_ text: String) { state.toggle(text) }

    // stops talking, used when a screen goes away
    static func stop() { state.stop() }
}

// whether remedy is reading out loud, for the play and stop buttons
@Observable
final class SpeakerState: NSObject, AVSpeechSynthesizerDelegate {

    private(set) var isSpeaking = false

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // starts reading, or stops if already reading
    func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            stop()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9     // a bit slower
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
