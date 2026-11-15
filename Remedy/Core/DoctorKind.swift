//
//  DoctorKind.swift
//  Remedy
//
//  the kinds of doctor a paper can come from, popular ones first
//  each one maps to who gave it and the kind of specialist the plan already knows
//

import Foundation

// the kinds of doctor a patient can pick for who gave a paper
nonisolated enum DoctorKind: String, CaseIterable, Identifiable {
    case primaryCare, surgeon, anesthesiologist, physicalTherapist, cardiologist, dermatologist
    case ophthalmologist, orthopedist, nephrologist, hematologist, endocrinologist, pulmonologist
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primaryCare: return "Primary care"
        case .surgeon: return "Surgeon"
        case .anesthesiologist: return "Anesthesiologist"
        case .physicalTherapist: return "Physical therapist"
        case .cardiologist: return "Cardiologist"
        case .dermatologist: return "Dermatologist"
        case .ophthalmologist: return "Ophthalmologist"
        case .orthopedist: return "Orthopedist"
        case .nephrologist: return "Kidney doctor"
        case .hematologist: return "Blood doctor"
        case .endocrinologist: return "Diabetes doctor"
        case .pulmonologist: return "Lung doctor"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .primaryCare: return "person.crop.circle"
        case .surgeon: return "cross.case"
        case .anesthesiologist: return "waveform.path.ecg"
        case .physicalTherapist: return "figure.walk"
        case .cardiologist: return "heart"
        case .dermatologist: return "hand.raised"
        case .ophthalmologist: return "eye"
        case .orthopedist: return "figure.stand"
        case .nephrologist: return "drop"
        case .hematologist: return "drop.fill"
        case .endocrinologist: return "syringe"
        case .pulmonologist: return "lungs"
        case .other: return "ellipsis.circle"
        }
    }

    // who gave the paper and which specialist, in the words the saved plan uses
    var source: (source: PaperSource, field: PaperField?) {
        switch self {
        case .primaryCare: return (.primaryCare, nil)
        case .surgeon, .anesthesiologist, .orthopedist: return (.surgeryTeam, nil)
        case .cardiologist: return (.specialist, .heart)
        case .nephrologist: return (.specialist, .kidney)
        case .hematologist: return (.specialist, .blood)
        case .endocrinologist: return (.specialist, .diabetes)
        case .pulmonologist: return (.specialist, .lungs)
        case .physicalTherapist, .dermatologist, .ophthalmologist, .other: return (.specialist, .other)
        }
    }

    // the kind to show for what the paper said, nil when the list has no better match than Other
    static func kind(source: PaperSource?, field: PaperField?) -> DoctorKind? {
        guard let source else { return nil }
        switch (source, field) {
        case (.primaryCare, _): return .primaryCare
        case (.surgeryTeam, _): return .surgeon
        case (.specialist, .heart?): return .cardiologist
        case (.specialist, .kidney?): return .nephrologist
        case (.specialist, .blood?): return .hematologist
        case (.specialist, .diabetes?): return .endocrinologist
        case (.specialist, .lungs?): return .pulmonologist
        case (.specialist, _): return .other
        case (.hospitalRecord, _), (.other, _): return nil
        }
    }
}
