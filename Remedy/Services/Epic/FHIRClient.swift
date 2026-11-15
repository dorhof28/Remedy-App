//
//  FHIRClient.swift
//  Remedy
//
//  reads the patient record from the hospital
//

import Foundation

// reads the patient's record from the hospital's fhir server
struct FHIRClient {

    let token: SMARTToken

    // no cache or cookies for medical data
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    // results come in pages we follow "next" up to this many pages
    private let maxPages = 5

    // the patients medicines
    func medicines() async throws -> [FHIRMedicationRequest] {
        let found: [FHIRMedicationRequest] = try await search("MedicationRequest", ["patient": token.patientID, "intent": "order"])   // Epic asks for the intent
        return found.filter { $0.resourceType == "MedicationRequest" }
    }

    // visits
    func visits() async throws -> [FHIRAppointment] {
        let found: [FHIRAppointment]
        do {
            found = try await search("Appointment", ["patient": token.patientID, "service-category": "appointment"])
        } catch EpicError.couldNotReach {
            found = try await search("Appointment", ["patient": token.patientID])
        }
        return found.filter { $0.resourceType == "Appointment" }
    }

    // the surgery itself
    func surgeries() async -> [FHIRAppointment] {
        let found: [FHIRAppointment]? = try? await search("Appointment", ["patient": token.patientID, "service-category": "surgery"])
        return (found ?? []).filter { $0.resourceType == "Appointment" }
    }

    // visit papers with readable words, newest first, a paper that fails to download is left out
    func papers() async -> [RecordPaper] {
        let found: [FHIRDocumentReference] = (try? await search("DocumentReference",
                                                               ["patient": token.patientID, "category": "clinical-note"])) ?? []
        var papers: [RecordPaper] = []
        for document in found where document.resourceType == "DocumentReference" && document.status != "entered-in-error" {
            guard papers.count < maxPapers,
                  let attachment = document.content?.compactMap(\.attachment).first(where: { FHIRMapper.isReadable($0) }),
                  let text = await words(in: attachment),
                  let paper = FHIRMapper.paper(document, text: text) else { continue }
            papers.append(paper)
        }
        return papers.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    // MARK: - Private

    // a long record has hundreds of notes, only the latest few matter for a surgery
    private let maxPapers = 10

    // inline words or the downloaded file, html turned into plain text
    private func words(in attachment: FHIRDocumentReference.Attachment) async -> String? {
        let raw: Data?
        if let inline = attachment.data {
            raw = Data(base64Encoded: inline)
        } else if let link = attachment.url {
            // a full link as is, "Binary/abc" under the fhir base
            guard let url = link.hasPrefix("http") ? URL(string: link) : EpicConfig.fhirBase.appending(path: link) else { return nil }
            raw = try? await download(url, accept: attachment.contentType ?? "text/plain")
        } else {
            raw = nil
        }
        guard let raw, let text = String(data: raw, encoding: .utf8) else { return nil }
        return (attachment.contentType ?? "").contains("html") ? PlainText.fromHTML(text) : text
    }

    // downloads a note's file with the token
    private func download(_ url: URL, accept: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        let (data, response) = try await Self.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw EpicError.couldNotReach }
        return data
    }

    // one search following "next" pages
    private func search<R: Decodable>(_ type: String, _ query: [String: String]) async throws -> [R] {
        var components = URLComponents(url: EpicConfig.fhirBase.appending(path: type), resolvingAgainstBaseURL: false)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var next = components?.url
        var results: [R] = []
        var pages = 0

        while let url = next, pages < maxPages {
            let bundle: FHIRBundle<R> = try await get(url)
            results += (bundle.entry ?? []).compactMap(\.resource)
            next = bundle.nextPage
            pages += 1
        }
        return results
    }

    // one authorized get, decoded
    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await Self.session.data(for: request) else {
            throw EpicError.couldNotReach
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 401: throw EpicError.signInExpired
        case 403: throw EpicError.notAllowed
        default: throw EpicError.couldNotReach
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw EpicError.unreadable
        }
    }
}
