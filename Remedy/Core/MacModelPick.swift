//
//  MacModelPick.swift
//  Remedy
//
//  picks the strongest model a Mac offers by its size in the name, embedding models never count
//  display help only, the patient can pick any model
//

import Foundation

// picks a sensible model from what the patient's mac lists
nonisolated enum MacModelPick {

    // billions of parameters from names like qwen3-32b, gemma-4-e4b or llama3.2-vision:11b, nil when not said
    static func size(of name: String) -> Double? {
        let lower = name.lowercased()
        guard let regex = try? NSRegularExpression(pattern: #"(?<![a-z0-9.])(?:a|e)?(\d+(?:\.\d+)?)b(?![a-z])"#) else { return nil }
        let range = NSRange(lower.startIndex..., in: lower)
        // the biggest number wins so 35b-a3b counts as 35
        let sizes = regex.matches(in: lower, range: range).compactMap { match -> Double? in
            guard let r = Range(match.range(at: 1), in: lower) else { return nil }
            return Double(lower[r])
        }
        return sizes.max()
    }

    // embedding speech and ranking models cannot read papers
    static func isChatModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        return !["embed", "rerank", "whisper", "tts", "bge-", "nomic"].contains { lower.contains($0) }
    }

    // the biggest chat model that fits, a known size beats an unknown one
    static func best(of names: [String], maxBillions: Double = 72) -> String? {
        let chat = names.filter(isChatModel)
        let sized = chat.compactMap { name in size(of: name).map { (name, $0) } }.filter { $0.1 <= maxBillions }
        if let top = sized.max(by: { $0.1 < $1.1 }) { return top.0 }
        return chat.first
    }

}
