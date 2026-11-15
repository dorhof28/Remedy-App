//
//  BuildKind.swift
//  Remedy
//
//  tells a testflight or xcode build from the app store one
//

import StoreKit

// tells a testflight or xcode build from the app store one, test tools only show in test builds
enum BuildKind {

    // testflight runs in the sandbox, xcode builds in the xcode environment
    static func isTest() async -> Bool {
        #if DEBUG
        return true
        #else
        guard case .verified(let transaction) = try? await AppTransaction.shared else { return false }
        return transaction.environment != .production
        #endif
    }
}
