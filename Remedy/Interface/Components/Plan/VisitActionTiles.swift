//
//  VisitActionTiles.swift
//  Remedy
//
//  call, directions and add to calendar for one visit, shared by the plan card and the visit page
//

import SwiftUI
import SwiftData

// call, directions and add to calendar for a visit
struct VisitActionTiles: View {
    let appointment: Appointment

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only Apple's new event screen
    @State private var isAddingToCalendar = false

    var body: some View {
        let viewModel = AppointmentDetailViewModel(appointment: appointment, now: AppClock.now())
        ActionTiles(tiles: tiles(viewModel))
            .sensoryFeedback(.success, trigger: viewModel.isInCalendar) { _, isIn in isIn }
            .sheet(isPresented: $isAddingToCalendar) {
                CalendarEventSheet(event: viewModel.calendarEvent(), onDone: { _ in
                    isAddingToCalendar = false
                }, onSaved: { id in
                    Motion.perform(reduceMotion) { viewModel.markAddedToCalendar(eventID: id, in: context) }
                })
                .ignoresSafeArea()
            }
    }

    private func tiles(_ viewModel: AppointmentDetailViewModel) -> [ActionTiles.Tile] {
        var result: [ActionTiles.Tile] = []
        if let phone = viewModel.phoneURL {
            result.append(.init(id: "call", title: viewModel.callTitle, symbol: "phone.fill") { openURL(phone) })
        }
        if let maps = viewModel.mapsURL {
            result.append(.init(id: "map", title: viewModel.directionsTitle, symbol: "mappin.and.ellipse") { openURL(maps) })
        }
        if viewModel.showsCalendarButton {
            result.append(.init(id: "calendar", title: viewModel.isInCalendar ? "In Calendar" : "Add to Calendar",
                                symbol: viewModel.isInCalendar ? "calendar.badge.checkmark" : "calendar",
                                isDone: viewModel.isInCalendar) { isAddingToCalendar = true })
        }
        return result
    }
}
