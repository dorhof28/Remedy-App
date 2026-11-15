//
//  PreviewSamples.swift
//  Remedy
//
//  demo only sample patient for previews
//

import SwiftUI
import SwiftData

// makes an in-memory database with the sample patient
private func makeSampleContainer(surgeryInDays: Int) throws -> ModelContainer {
    let schema = Schema(RemedySchema.models)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: configuration)
    SamplePlan.insert(into: container.mainContext, surgeryInDays: surgeryInDays)
    return container
}

// surgery in 4 days the ibuprofen / naproxen stop starts today
struct BeforeSurgerySample: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        try makeSampleContainer(surgeryInDays: 4)
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

// surgery was 3 days ago doses goals and rules are showing
struct AfterSurgerySample: PreviewModifier {
    static func makeSharedContext() throws -> ModelContainer {
        try makeSampleContainer(surgeryInDays: -3)
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    @MainActor static var beforeSurgerySample: Self = .modifier(BeforeSurgerySample())
    @MainActor static var afterSurgerySample: Self = .modifier(AfterSurgerySample())
}
