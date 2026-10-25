//
//  RootView.swift
//  Remedy
//
//  Created by Dorron Hoffman on 10/24/26.
//
//  scan flow when theres no plan otherwise the tabs or simple home
//

import SwiftUI
import SwiftData

struct RootView: View {

    @Query private var plans: [CarePlan]

    // classic or Simple picked in Settings
    @AppStorage(AppLook.storageKey) private var look: AppLook = .classic

    var body: some View {
        // themselves as soon as the first plan is saved
        if plans.isEmpty {
            ScanFlowView()
                .transition(.opacity)
        } else if look == .simple {
            SimpleRootView()
                .transition(.opacity)
        } else {
            tabs
                .transition(.opacity)
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Today", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Medicines", systemImage: "pills.fill") {
                MedicinesView()
            }
            Tab("Plan", systemImage: "calendar") {
                PlanView()
            }
            Tab("Ask", systemImage: "bubble.left.and.text.bubble.right.fill") {
                AskView()
            }
        }
    }
}

#Preview(traits: .beforeSurgerySample) {
    RootView()
}
