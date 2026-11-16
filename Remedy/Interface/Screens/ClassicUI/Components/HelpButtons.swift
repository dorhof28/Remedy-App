//
//  HelpButtons.swift
//  Remedy
//
//  the toolbar on every classic tab root: Help and Settings (or Clear Chat on Ask) as icons on the right
//

import SwiftUI

extension View {
    // help is never more than one tap away, both are icons with spoken labels
    func helpButtons(showsSettings: Bool = true, clearChat: (() -> Void)? = nil) -> some View {
        modifier(TabRootToolbar(showsSettings: showsSettings, clearChat: clearChat))
    }
}

// help and settings buttons on each tab's top bar
private struct TabRootToolbar: ViewModifier {
    let showsSettings: Bool
    let clearChat: (() -> Void)?

    // UI only which sheet is open
    @State private var isShowingHelp = false
    @State private var isShowingSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                // both icons sit on the right, help first and settings at the edge
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingHelp = true } label: {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Color.toneRed)
                    }
                    .accessibilityLabel("Help")
                    .accessibilityHint("Call 911, call your care team or see when to call")
                    .accessibilityIdentifier("toolbar-help")
                }
                if let clearChat {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear Chat", action: clearChat)
                            .foregroundStyle(Color.ink)
                    }
                } else if showsSettings {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isShowingSettings = true } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(Color.ink)
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("toolbar-settings")
                    }
                }
            }
            .sheet(isPresented: $isShowingHelp) { HelpView() }
            .sheet(isPresented: $isShowingSettings) { SettingsView() }
    }
}
