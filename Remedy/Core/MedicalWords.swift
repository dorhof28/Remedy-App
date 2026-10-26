//
//  MedicalWords.swift
//  Remedy
//
//  common medicine and care words so we never hide them as names
//

import Foundation

nonisolated enum MedicalWords {

    // common surgery medicines generic and brand lower case
    static let medicines: Set<String> = [
        "acetaminophen", "tylenol", "ibuprofen", "advil", "motrin", "naproxen", "aleve", "aspirin", "ecotrin", "bayer",
        "celecoxib", "celebrex", "meloxicam", "mobic", "ketorolac", "toradol", "diclofenac", "voltaren",
        "oxycodone", "percocet", "roxicodone", "hydrocodone", "norco", "vicodin", "tramadol", "ultram",
        "morphine", "hydromorphone", "dilaudid", "codeine", "gabapentin", "neurontin", "pregabalin", "lyrica",
        "warfarin", "coumadin", "jantoven", "apixaban", "eliquis", "rivaroxaban", "xarelto", "dabigatran", "pradaxa",
        "clopidogrel", "plavix", "heparin", "enoxaparin", "lovenox", "ticagrelor", "brilinta",
        "metformin", "glucophage", "insulin", "lantus", "humalog", "novolog", "glipizide", "jardiance", "ozempic",
        "semaglutide", "wegovy", "mounjaro", "tirzepatide", "trulicity", "farxiga",
        "lisinopril", "losartan", "amlodipine", "metoprolol", "atenolol", "carvedilol", "hydrochlorothiazide",
        "furosemide", "lasix", "spironolactone", "atorvastatin", "lipitor", "simvastatin", "rosuvastatin", "crestor",
        "levothyroxine", "synthroid", "prednisone", "methylprednisolone", "medrol", "dexamethasone",
        "omeprazole", "prilosec", "pantoprazole", "protonix", "famotidine", "pepcid", "ondansetron", "zofran",
        "docusate", "colace", "senna", "senokot", "miralax", "polyethylene", "bisacodyl", "dulcolax",
        "cephalexin", "keflex", "cefazolin", "amoxicillin", "augmentin", "clindamycin", "doxycycline", "bactrim",
        "sertraline", "zoloft", "fluoxetine", "prozac", "escitalopram", "lexapro", "trazodone", "melatonin",
        "diphenhydramine", "benadryl", "loratadine", "claritin", "cetirizine", "zyrtec", "albuterol", "ventolin",
        "fish", "vitamin", "multivitamin", "supplements", "turmeric", "ginkgo", "ginseng", "garlic", "ginger",
        "chlorhexidine", "hibiclens", "ice", "tens",
    ]

    // words near a name that mean its a doctor or nurse not the patient
    static let careTitles: [String] = [
        "dr", "dr.", "doctor", "md", "m.d.", "do", "rn", "np", "pa", "pa-c", "aprn", "fnp", "crna", "dpt",
        "phd", "dds", "surgeon", "physician", "provider", "nurse", "attending", "resident", "anesthesia",
        "anesthesiologist", "therapist", "pharmacist", "coordinator", "office", "clinic", "hospital", "center",
        "medical", "health", "orthopedic", "orthopaedic", "surgery",
    ]

    // words that look like names but never are
    static let notNames: Set<String> = [
        "patient", "name", "date", "birth", "phone", "home", "call", "please", "your", "you", "the", "and",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august", "september", "october",
        "november", "december", "morning", "night", "surgery", "hospital", "instructions", "mychart",
    ]

    // a word we must never black out
    static func isProtected(_ word: String) -> Bool {
        let lower = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        return medicines.contains(lower) || notNames.contains(lower) || careTitles.contains(lower)
    }

    // medicine names for vision so it spells them right
    static var visionWords: [String] {
        medicines.filter { $0.count > 4 }.map { $0.prefix(1).uppercased() + $0.dropFirst() }.sorted()
    }
}
