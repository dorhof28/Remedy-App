//
//  PKCE.swift
//  Remedy
//
//  pkce secret for the epic sign in
//

import CryptoKit
import Foundation
import Security

// the one time secret that proves the token request comes from this app
struct PKCE {
    let verifier: String
    let challenge: String

    // a new random one for each sign-in
    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        self.init(verifier: Self.base64URL(Data(bytes)))
    }

    // from a known verifier
    init(verifier: String) {
        self.verifier = verifier
        self.challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    // base64 safe for urls
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
