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

    // no cache no cookies gives up after 60 seconds
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    // sends the prompt and returns the JSON answer
    static func generateJSON(instructions: String, prompt: String, schema: [String: Any], apiKey: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "systemInstruction": ["parts": [["text": instructions]]],
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0,
                "responseMimeType": "application/json",
                "responseSchema": schema,
            ],
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

        // the JSON we asked for is the text of the first answer
        let answer = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = answer.candidates?.first?.content?.parts?.first?.text,
              answer.promptFeedback?.blockReason == nil else {
            throw PlanReaderError.couldNotRead
        }
        return Data(text.utf8)
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
