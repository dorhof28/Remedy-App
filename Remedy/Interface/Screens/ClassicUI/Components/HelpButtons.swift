//
//  HelpButtons.swift
//  Remedy
//
//  help and settings buttons every tab shares
//

import SwiftUI

struct HelpButtons: ViewModifier {
    let showsSettings: Bool

    // UI only which sheet is open
    @State private var isShowingHelp = false
    @State private var isShowingSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingHelp = true
                    } label: {
                        Label("Get help", systemImage: "cross.case.fill")
                    }
                    .tint(.red)
                    .accessibilityHint("Call 911 or your care team")
                }
                if showsSettings {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingHelp) {
                HelpView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
    }
}

extension View {
    // adds the help button and settings if needed
    func helpButtons(showsSettings: Bool = false) -> some View {
        modifier(HelpButtons(showsSettings: showsSettings))
    }
}
