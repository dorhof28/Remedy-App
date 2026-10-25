//
//  FamilySheetPage.swift
//  Remedy
//
//  the printable share with family page
//

import SwiftUI

struct FamilySheetPage: View {
    let sheet: FamilySheet

    // US Letter in PDF points
    static let size = CGSize(width: 612, height: 792)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // top
            VStack(alignment: .leading, spacing: 3) {
                Text(sheet.title)
                    .font(.system(size: 22, weight: .bold))
                if !sheet.subtitle.isEmpty {
                    Text(sheet.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(sheet.madeOn)
                    .font(.system(size: 9))
                    .foregroundStyle(.gray)
            }

            Rectangle().fill(Color.remedyTeal).frame(height: 2)

            // two columns medicines | plan
            HStack(alignment: .top, spacing: 20) {
                column(sheet.left)
                column(sheet.right)
            }

            Spacer(minLength: 0)

            Text(sheet.footer)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.gray)
        }
        .padding(36)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }

    private func column(_ blocks: [FamilyBlock]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                FamilyBlockView(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// "DON'T TAKE" + its lines
struct FamilyBlockView: View {
    let block: FamilyBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(block.title.uppercased(), systemImage: block.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(block.tone == .neutral ? Color.gray : block.tone.color)
            ForEach(block.lines) { line in
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.title)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                    if !line.detail.isEmpty {
                        Text(line.detail)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.gray)
                            .lineLimit(2)
                    }
                }
            }
            if !block.moreText.isEmpty {
                Text(block.moreText)
                    .font(.system(size: 9).italic())
                    .foregroundStyle(.gray)
            }
        }
    }
}

#Preview {
    FamilySheetPage(sheet: FamilySheet(
        title: "Remedy plan \u{00B7} Surgery in 4 days", subtitle: "Thursday, October 29 \u{00B7} Knee replacement",
        madeOn: "Made Oct 25.", left: [
            FamilyBlock(title: "Don\u{2019}t take", symbol: "hand.raised.fill", tone: .stop,
                        lines: [FamilyLine(title: "Ibuprofen (Advil)", detail: "Stopped since Thu, Oct 22")], moreText: ""),
        ], right: [], footer: "Not medical advice. In an emergency, call 911."))
}

// MARK: - The page, shrunk to fit the phone's width (for the preview)

// the page shrunk to fit the phone
struct FamilySheetPreview: View {
    let sheet: FamilySheet

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / FamilySheetPage.size.width
            FamilySheetPage(sheet: sheet)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: FamilySheetPage.size.height * scale, alignment: .topLeading)
        }
        .aspectRatio(FamilySheetPage.size.width / FamilySheetPage.size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview of the page")
    }
}
