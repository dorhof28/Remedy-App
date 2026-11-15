//
//  HelpButtons.swift
//  Remedy
//
//  the toolbar on every classic tab root: Help on the left, Settings (or Clear Chat on Ask) on the right
//

import SwiftUI

extension View {
    // help is never more than one tap away, settings is a labeled button
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { isShowingHelp = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "phone")
                                .foregroundStyle(Color.toneRed)
                            Text("Help")
                                .foregroundStyle(Color.ink)
                        }
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
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape")
                                Text("Settings")
                            }
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
