//
//  GeminiClient.swift
//  Remedy
//
//  talks to the gemini api
//

import Foundation

enum GeminiClient {

    // latest flash so it keeps working when google retires a model
    static let model = "gemini-flash-latest"

    private static let endpoint = URL(string:
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!

    // no cache no cookies gives up after 90 seconds since pictures take longer
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 90
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    // sends the prompt and returns the JSON answer
    static func generateJSON(instructions: String, prompt: String, schema: [String: Any], apiKey: String) async throws -> Data {
        let text = try await send(instructions: instructions, parts: [["text": prompt]], config: [
            "temperature": 0,
            "responseMimeType": "application/json",
            "responseSchema": schema,
        ], apiKey: apiKey)
        return Data(text.utf8)
    }

    // sends pictures plus a prompt and returns plain text
    // only ever gets pictures that were blacked out on the phone
    static func generateText(instructions: String, prompt: String, jpegs: [Data], apiKey: String) async throws -> String {
        let pictures: [[String: Any]] = jpegs.map {
            ["inlineData": ["mimeType": "image/jpeg", "data": $0.base64EncodedString()]]
        }
        return try await send(instructions: instructions, parts: pictures + [["text": prompt]],
                              config: ["temperature": 0], apiKey: apiKey)
    }

    // MARK: - Private

    private static func send(instructions: String, parts: [[String: Any]], config: [String: Any], apiKey: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "systemInstruction": ["parts": [["text": instructions]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": config,
        ] as [String: Any])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PlanReaderError.offline
        }

        // turn Google's answer codes into words the patient understands
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: break
        case 400, 401, 403: throw PlanReaderError.keyRejected
        case 429, 500...599: throw PlanReaderError.busy
        default: throw PlanReaderError.couldNotRead
        }

        // the answer is the text of the first candidate
        let answer = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = answer.candidates?.first?.content?.parts?.compactMap(\.text).joined(),
              !text.isEmpty, answer.promptFeedback?.blockReason == nil else {
            throw PlanReaderError.couldNotRead
        }
        return text
    }
}

// only the parts of Google's reply we use
private nonisolated struct GeminiResponse: Decodable {
    struct Candidate: Decodable { let content: Content? }
    struct Content: Decodable { let parts: [Part]? }
    struct Part: Decodable { let text: String? }
    struct Feedback: Decodable { let blockReason: String? }

    let candidates: [Candidate]?
    let promptFeedback: Feedback?
}
