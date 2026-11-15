//
//  RemedyActivity.swift
//  Remedy
//
//  what a busy-day Live Activity holds, shared with the widget
//

import ActivityKit
import Foundation

// what the live activity shows, shared with the widget extension
nonisolated struct RemedyActivityAttributes: ActivityAttributes {

    // one row on the activity's checklist
    nonisolated struct Step: Codable, Hashable {
        let title: String
        let isDone: Bool
    }

    // what changes while the activity runs
    nonisolated struct ContentState: Codable, Hashable {
        var headline: String            // "Clear liquids end in"
        var countdownTo: Date?          // counts down to this
        var steps: [Step]               // what is due, in order
        var nextTitle: String? = nil    // the next thing to do
        var doneCount: Int? = nil       // steps ticked so far
        var totalCount: Int? = nil
        var detail: String? = nil       // "Nothing to eat. Clear liquids until 4:30 AM."
        var showsHeadlineOnly: Bool? = nil  // surgery morning shows the arrival line, not the step list
    }

    var dayTitle: String                // "Surgery day"
    var directionsAddress: String?      // opens Apple Maps
    var placeName: String? = nil        // "Lakeside General"
}
