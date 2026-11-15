//
//  AppleAI.swift
//  Remedy
//
//  which apple ai model is ready
//

import Foundation
import FoundationModels

// which apple model is ready on this phone
enum AppleAI {

    // off until Apple approves our Private Cloud Compute entitlement
    static let usesCloud = false

    // is the cloud model ready
    static var isCloudAvailable: Bool {
        guard usesCloud else { return false }
        if case .available = PrivateCloudComputeLanguageModel().availability { return true }
        return false
    }

    // is the on-phone model ready
    static var isPhoneAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
}
