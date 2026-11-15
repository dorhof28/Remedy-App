//
//  CalendarEventSheet.swift
//  Remedy
//
//  apples new event screen filled in for a visit, it has its own calendar picker
//

import EventKit
import EventKitUI
import SwiftUI

// apple's add event sheet for one visit
struct CalendarEventSheet: UIViewControllerRepresentable {
    let event: EKEvent
    // true = the patient tapped Add
    let onDone: (Bool) -> Void
    // the id of the event that was saved
    var onSaved: (String?) -> Void = { _ in }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = CalendarService.store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone, onSaved: onSaved) }

    // closes the sheet when done
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: (Bool) -> Void
        let onSaved: (String?) -> Void
        init(onDone: @escaping (Bool) -> Void, onSaved: @escaping (String?) -> Void) {
            self.onDone = onDone
            self.onSaved = onSaved
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            if action == .saved {
                // next time the sheet starts on the calendar they picked
                CalendarService.remember(controller.event?.calendar)
                onSaved(controller.event?.eventIdentifier)
            }
            onDone(action == .saved)
        }
    }
}
