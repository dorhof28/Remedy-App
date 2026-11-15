//
//  PhotoTrack.swift
//  Remedy
//
//  something the patient watches over time with dated photos
//

import Foundation
import SwiftData

// a named series of photos, like the cut on the knee
@Model
final class PhotoTrack {

    var id: UUID = UUID()

    // the patient's name for it like incision or swelling
    var name: String = ""

    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PhotoEntry.track)
    var entries: [PhotoEntry] = []

    init(name: String) {
        self.name = name
    }
}

// one photo in a series, saved as a file on the phone
@Model
final class PhotoEntry {

    var id: UUID = UUID()

    // when the photo was taken
    var takenAt: Date = Date()

    var note: String = ""

    // stays inside the app, never in the photo library
    @Attribute(.externalStorage) var imageData: Data?

    var track: PhotoTrack?

    init(imageData: Data, takenAt: Date = Date(), note: String = "") {
        self.imageData = imageData
        self.takenAt = takenAt
        self.note = note
    }
}
