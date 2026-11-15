//
//  FamilySheetPage.swift
//  Remedy
//
//  the printable share with family page
//

import SwiftUI

// one printed family sheet page, drawn into the pdf
struct FamilySheetPage: View {
    let sheet: FamilySheet

    // US Letter in PDF points
    static let size = CGSize(width: 612, height: 792)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // top
            VStack(alignment: .leading, spacing: 3) {
                Text(sheet.title)
                    .font(.system(size: 28, weight: .bold))
                if !sheet.subtitle.isEmpty {
                    Text(sheet.subtitle)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(sheet.madeOn)
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }

            Rectangle().fill(Color.remedyTeal).frame(height: 2)

            // cover summary
            if !sheet.cover.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(sheet.cover) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(line.title.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.remedyTeal)
                                .frame(width: 80, alignment: .leading)
                            Text(line.detail)
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            // two columns medicines | plan
            HStack(alignment: .top, spacing: 22) {
                column(sheet.left)
                column(sheet.right)
            }

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline) {
                Text(sheet.footer)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.gray)
                Spacer(minLength: 8)
                if !sheet.pageText.isEmpty {
                    Text(sheet.pageText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(32)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }

    private func column(_ blocks: [FamilyBlock]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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
        VStack(alignment: .leading, spacing: 6) {
            Label(block.title.uppercased(), systemImage: block.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(block.tone == .neutral ? Color.gray : block.tone.color)
            ForEach(block.lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if line.hasCheckbox {
                        Image(systemName: "square")
                            .font(.system(size: 14))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(4)
                        if !line.detail.isEmpty {
                            Text(line.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.25))
                                .lineLimit(4)
                        }
                    }
                }
            }
            if !block.moreText.isEmpty {
                Text(block.moreText)
                    .font(.system(size: 11).italic())
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
