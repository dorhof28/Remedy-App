//
//  MacConnector.swift
//  Remedy
//
//  finds LM Studio, oMLX or Ollama on the patient's own Mac over the home network and lists its models
//  nothing is sent here, only the list of models is asked for
//

import Foundation

// the apps that serve a model from a Mac, tried in this order
enum MacServer: String, CaseIterable, Sendable {
    case lmStudio, omlx, ollama

    var name: String {
        switch self {
        case .lmStudio: return "LM Studio"
        case .omlx: return "oMLX"
        case .ollama: return "Ollama"
        }
    }

    nonisolated var port: Int {
        switch self {
        case .lmStudio: return 1234
        case .omlx: return 8000
        case .ollama: return 11434
        }
    }
}

// a mac server that answered and its models
struct MacConnection: Equatable, Sendable {
    let server: MacServer
    let baseURL: URL        // like http://dorrons-macbook.local:1234/v1
    let models: [String]
}

// why the mac could not be reached
enum MacConnectError: Error, Equatable {
    case noName
    case notFound           // nothing answered on either port
    case noModels(MacServer)
    case needsKey(MacServer)    // it answered but wants its api key
}

// finds lm studio, omlx or ollama by name on the home network
nonisolated enum MacConnector {

    // every address to try for what was typed, LM Studio first since it is the usual one
    static func candidates(for typed: String) -> [(MacServer, URL)] {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        if text.lowercased().hasPrefix("http") {
            // a full address is tried as typed
            guard var url = URL(string: text) else { return [] }
            if !url.path.hasSuffix("/v1") { url = url.appendingPathComponent("v1") }
            let server = MacServer.allCases.first { $0.port == url.port } ?? .lmStudio
            return [(server, url)]
        }
        // a Mac name like Dorrons-MacBook becomes dorrons-macbook.local, spaces become dashes like macOS does
        text = text.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "\u{2019}", with: "")
        let host = text.contains(".") || text.allSatisfy({ $0.isNumber || $0 == "." }) ? text : "\(text).local"
        return MacServer.allCases.compactMap { server in
            URL(string: "http://\(host):\(server.port)/v1").map { (server, $0) }
        }
    }

    // asks each address for its models, the first that answers wins
    // the key is only sent to the Mac that was typed, never anywhere else
    static func connect(_ typed: String, key: String = "",
                        session: URLSession = quickSession) async -> Result<MacConnection, MacConnectError> {
        let tries = candidates(for: typed)
        guard !tries.isEmpty else { return .failure(.noName) }
        var locked: MacServer?
        for (server, base) in tries {
            switch await models(at: base, key: key, session: session) {
            case .none: continue
            case .locked: locked = locked ?? server
            case .list(let models):
                if models.isEmpty { return .failure(.noModels(server)) }
                return .success(MacConnection(server: server, baseURL: base, models: models))
            }
        }
        return .failure(locked.map(MacConnectError.needsKey) ?? .notFound)
    }

    // what one address answered
    enum Answer: Equatable {
        case none                   // nothing answered
        case locked                 // it wants a key
        case list([String])
    }

    // the openai style list of models
    static func models(at base: URL, key: String, session: URLSession) async -> Answer {
        struct List: Decodable {
            struct Item: Decodable { let id: String }
            let data: [Item]
        }
        var request = URLRequest(url: base.appendingPathComponent("models"))
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 { return .locked }
            guard status == 200, let list = try? JSONDecoder().decode(List.self, from: data) else { return .none }
            return .list(list.data.map(\.id))
        } catch {
            return .none
        }
    }

    // a short wait so a wrong name fails in seconds
    static let quickSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    // a big model on a Mac can think for minutes on long papers
    static var planningConfiguration: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 1200
        return config
    }
}
