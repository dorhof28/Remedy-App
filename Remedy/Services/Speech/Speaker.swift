//
//  Speaker.swift
//  Remedy
//
//  reads text out loud
//

import AVFoundation

enum Speaker {

    private static let synthesizer = AVSpeechSynthesizer()

    // says the text
    static func toggle(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9     // a bit slower
        synthesizer.speak(utterance)
    }
}
