//
//  SMARTAuth.swift
//  Remedy
//
//  signs the patient in to their hospital
//

import AuthenticationServices
import Foundation
import SwiftUI

// what sign-in gives us
struct SMARTToken {
    let accessToken: String
    let patientID: String
}

// smart on fhir sign in: find the endpoints, sign in on the web, swap the code for a token
enum SMARTAuth {

    // full sign in returns a token
    static func signIn(using webAuth: WebAuthenticationSession) async throws -> SMARTToken {
        let endpoints = try await discover()
        let pkce = PKCE()
        let state = UUID().uuidString          // checked when Epic sends us back

        // 2 the hospital's login page with everything SMART asks for
        guard var components = URLComponents(url: endpoints.authorize, resolvingAgainstBaseURL: false) else {
            throw EpicError.couldNotReach
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: EpicConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: EpicConfig.redirectURI),
            URLQueryItem(name: "scope", value: EpicConfig.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "aud", value: EpicConfig.fhirBase.absoluteString),   // Epic requires this
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let loginURL = components.url else { throw EpicError.couldNotReach }

        // 3 apple's secure sheet
        let callback: URL
        do {
            callback = try await webAuth.authenticate(using: loginURL,
                                                      callback: .customScheme(EpicConfig.callbackScheme),
                                                      preferredBrowserSession: .ephemeral,
                                                      additionalHeaderFields: [:])
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw EpicError.cancelled
        }

        // back from Epic check it's our sign-in then take the code
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard value("state") == state else { throw EpicError.signInFailed }
        guard value("error") == nil, let code = value("code") else { throw EpicError.signInFailed }

        return try await exchange(code: code, verifier: pkce.verifier, at: endpoints.token)
    }

    // MARK: - Steps

    // where to sign in and where to swap the code for a token
    private struct Endpoints {
        let authorize: URL
        let token: URL
    }

    // 1 asks the hospital for its login and token addresses
    private static func discover() async throws -> Endpoints {
        // the server's smart configuration
        struct Configuration: Decodable {
            let authorization_endpoint: URL
            let token_endpoint: URL
        }
        let url = EpicConfig.fhirBase.appending(path: ".well-known/smart-configuration")
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await FHIRClient.session.data(for: request),
              let config = try? JSONDecoder().decode(Configuration.self, from: data) else {
            throw EpicError.couldNotReach
        }
        return Endpoints(authorize: config.authorization_endpoint, token: config.token_endpoint)
    }

    // 4 swaps the one-time code for a token
    private static func exchange(code: String, verifier: String, at tokenURL: URL) async throws -> SMARTToken {
        // the token and the patient it is for
        struct TokenResponse: Decodable {
            let access_token: String
            let patient: String?
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": EpicConfig.redirectURI,
            "client_id": EpicConfig.clientID,
            "code_verifier": verifier,
        ])
        guard let (data, response) = try? await FHIRClient.session.data(for: request) else {
            throw EpicError.couldNotReach
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let token = try? JSONDecoder().decode(TokenResponse.self, from: data),
              let patient = token.patient else {
            throw EpicError.signInFailed
        }
        return SMARTToken(accessToken: token.access_token, patientID: patient)
    }

    // form encodes the body
    private static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}
