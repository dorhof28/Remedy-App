//
//  FHIRClient.swift
//  Remedy
//
//  reads the patient record from the hospital
//

import Foundation

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
        let found: [FHIRMedicationRequest] = try await search("MedicationRequest", ["patient": token.patientID])
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

    // MARK: - Private

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
