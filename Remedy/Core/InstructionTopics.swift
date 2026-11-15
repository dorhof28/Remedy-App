//
//  InstructionTopics.swift
//  Remedy
//
//  sorts a paper instruction into a plain topic like eating and drinking or wound care
//  display only, plain words, the paper quote is never changed
//

import Foundation

// the topics instructions are grouped by on the instructions screen
nonisolated enum InstructionTopic: String, CaseIterable, Sendable {
    case food, bathing, activity, driving, wound, medicines, bring, other

    var title: String {
        switch self {
        case .food: return "Eating & drinking"
        case .bathing: return "Bathing"
        case .activity: return "Moving & lifting"
        case .driving: return "Driving"
        case .wound: return "Wound care"
        case .medicines: return "Medicines"
        case .bring: return "What to bring"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .bathing: return "shower.fill"
        case .activity: return "figure.walk"
        case .driving: return "car.fill"
        case .wound: return "bandage.fill"
        case .medicines: return "pills.fill"
        case .bring: return "bag.fill"
        case .other: return "text.bubble.fill"
        }
    }

    // first topic whose words show up, checked in this order so "bring your pills" is bring
    static func of(_ text: String) -> InstructionTopic {
        let words = " " + text.lowercased()
            .map { $0.isLetter || $0 == "'" || $0 == "\u{2019}" ? $0 : " " }
            .reduce(into: "") { $0.append($1) } + " "
        for topic in order where clues[topic, default: []].contains(where: { words.contains(" \($0)") }) {
            return topic
        }
        return .other
    }

    private static let order: [InstructionTopic] = [.bring, .driving, .bathing, .wound, .food, .activity, .medicines]

    // word starts, so "eat" also finds "eating"
    private static let clues: [InstructionTopic: [String]] = [
        .bring: ["bring", "pack ", "wear loose", "leave jewel", "leave valuables", "remove jewel", "photo id", "insurance card"],
        .driving: ["driv", "car ", "ride home", "someone to take you", "operate machin"],
        .bathing: ["shower", "bath", "tub", "swim", "pool", "hot tub", "soak", "wash your hair", "chlorhexidine", "hibiclens"],
        .wound: ["wound", "incision", "dressing", "bandage", "stitch", "suture", "staple", "drain", "steri", "scar"],
        .food: ["eat", "food", "drink", "liquid", "water", "juice", "coffee", "alcohol", "gum", "candy", "meal", "diet", "fluid", "nothing by mouth", "npo"],
        .activity: ["lift", "walk", "exercise", "sport", "run", "climb", "stairs", "bend", "work", "sex", "activit", "rest", "sleep", "pound", "lbs"],
        .medicines: ["medic", "pill", "tablet", "dose", "aspirin", "ibuprofen", "vitamin", "supplement"]
    ]
}
