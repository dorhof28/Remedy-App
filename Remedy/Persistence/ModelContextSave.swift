//
//  ModelContextSave.swift
//  Remedy
//
//  backup save if swiftdata doesnt save on its own
//

import Foundation
import SwiftData

extension ModelContext {

// give error instead of crashing app - fixed from testing
    func saveNow() {
        do {
            try save()
        } catch {
            print("Remedy: could not save: \(error)")
        }
    }
}
