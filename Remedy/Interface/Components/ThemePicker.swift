//
//  ThemePicker.swift
//  Remedy
//
//  glass swatches to pick the app theme
//

import SwiftUI

struct ThemePicker: View {
    @Binding var theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTheme.allCases) { option in
                Button {
                    theme = option
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(LinearGradient(colors: option.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                            .overlay {
                                if theme == option {
                                    Image(systemName: "checkmark")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                            }
                            .padding(5)
                            .glassEffect(.regular.interactive(), in: .circle)
                        Text(option.title)
                            .font(.caption.weight(theme == option ? .semibold : .regular))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(theme == option ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
