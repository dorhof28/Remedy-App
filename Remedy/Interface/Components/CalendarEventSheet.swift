//
//  CalendarEventSheet.swift
//  Remedy
//
//  apples new event screen filled in for a visit
//

import EventKit
import EventKitUI
import SwiftUI

struct CalendarEventSheet: UIViewControllerRepresentable {
    let event: EKEvent
    // true = the patient tapped Add
    let onDone: (Bool) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = CalendarService.store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    // closes the sheet when done
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: (Bool) -> Void
        init(onDone: @escaping (Bool) -> Void) { self.onDone = onDone }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone(action == .saved)
        }
    }
}
