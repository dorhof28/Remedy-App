//
//  ModelAliases.swift
//  Remedy
//
//  the generic core rules bound to the saved models
//

import SwiftData

typealias DayEvent = DayEventOf<CarePlan>
typealias AgendaItem = AgendaItemOf<CarePlan>
typealias Agenda = AgendaOf<CarePlan>
typealias ReminderItem = ReminderItemOf<PersistentIdentifier>
