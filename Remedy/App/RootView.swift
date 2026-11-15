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

// the tabs in the classic look
enum RemedyTab: Hashable {
    case today, medicines, plan, ask
}

// lets a screen inside a tab switch tabs, nil when there are no tabs
private struct SwitchTabKey: EnvironmentKey {
    static let defaultValue: ((RemedyTab) -> Void)? = nil
}

extension EnvironmentValues {
    var switchTab: ((RemedyTab) -> Void)? {
        get { self[SwitchTabKey.self] }
        set { self[SwitchTabKey.self] = newValue }
    }

}

// picks the look, shows the lock, the demo banner and the first-run flow
struct RootView: View {

    @Query private var plans: [CarePlan]

    init() {
        AppLook.registerDefault()
        AppLookMode.registerDefault()
    }

    @Environment(\.scenePhase) private var scenePhase
    // UI only the open tab
    @State private var selectedTab: RemedyTab = RootView.startTab
    // DEBUG ONLY opens demo mode straight away for screenshots
    @State private var isShowingDemo = RootView.opensDemo
    @State private var lock = AppLock.live()
    @AppStorage(AppLock.settingKey) private var lockOn = false

    // classic or Simple picked in Settings
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple
    // automatic, classic or simple picked in Settings, automatic follows the text size
    @AppStorage(AppLookMode.storageKey) private var lookMode: AppLookMode = .automatic
    @AppStorage(AppLookMode.noteShownKey) private var autoNoteShown = false
    @AppStorage(AppLookMode.noteOpenKey) private var autoNoteOpen = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            screens
        }
            .tint(Color.accentInk)
            .demoEditScreen()
            .sheet(isPresented: $isShowingDemo) {
                DemoModeView()
            }
            .onAppear(perform: resolveLook)
            .onChange(of: typeSize) { resolveLook() }
            .onChange(of: lookMode) { resolveLook() }
            .overlay {
                if lock.isLocked || lock.isCovered { lockScreen }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .inactive { lock.sceneBecameInactive() }
                if phase == .background { lock.didEnterBackground() }
                if phase == .active {
                    lock.sceneBecameActive()
                    if lock.isLocked { Task { await lock.unlock() } }
                }
            }
            .onChange(of: lockOn) { lock.settingChanged() }
            .task { if lock.isLocked { await lock.unlock() } }
    }

    // automatic picks the look from the text size, the first switch to simple leaves a note open
    private func resolveLook() {
        let next = lookMode.look(largeText: typeSize.isAccessibilitySize)
        if lookMode == .automatic, next == .simple, look != .simple, !autoNoteShown {
            autoNoteShown = true
            autoNoteOpen = true
        }
        if look != next { look = next }
    }

    // covers everything until Face ID or the passcode works
    private var lockScreen: some View {
        LockScreenView(failed: lock.failed) { Task { await lock.unlock() } }
    }

    @ViewBuilder
    private var screens: some View {
        // no plan yet is always the classic first screens, the saved look starts once the plan is saved
        if plans.isEmpty {
            ScanFlowView()
                .transition(.opacity)
        } else if look == .simple {
            // the one-time note sits above home and pushes it down
            VStack(spacing: 0) {
                if autoNoteOpen {
                    LookSwitchedNote(onClassic: { autoNoteOpen = false; lookMode = .classic; resolveLook() },
                                     onClose: { autoNoteOpen = false })
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                        .padding(.top, 8)
                }
                SimpleRootView()
            }
            .background(RemedyBackground().ignoresSafeArea())
            .transition(.opacity)
        } else {
            tabs
                .transition(.opacity)
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max", value: RemedyTab.today) {
                TodayView()
            }
            Tab("Medicines", systemImage: "pill", value: RemedyTab.medicines) {
                MedicinesView()
            }
            Tab("Plan", systemImage: "calendar", value: RemedyTab.plan) {
                PlanView()
            }
            Tab("Ask", systemImage: "questionmark.bubble", value: RemedyTab.ask) {
                AskView()
            }
        }
        .environment(\.switchTab, { selectedTab = $0 })
    }

    // DEBUG ONLY -startTab medicines|plan|ask opens that tab for screenshots
    private static var startTab: RemedyTab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "startTab") {
        case "medicines": return .medicines
        case "plan": return .plan
        case "ask": return .ask
        default: return .today
        }
        #else
        return .today
        #endif
    }

    // DEBUG ONLY -openDemoMode YES shows the demo mode sheet
    static var opensDemo: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "openDemoMode")
        #else
        return false
        #endif
    }
}

#Preview(traits: .beforeSurgerySample) {
    RootView()
}
