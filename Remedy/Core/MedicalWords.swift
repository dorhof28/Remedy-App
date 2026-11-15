//
//  MedicalWords.swift
//  Remedy
//
//  common medicine and care words so we never hide them as names
//

import Foundation

// medicine and medical words the spell fixer and name finder must never change or hide
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
        "stop", "take", "taking", "do", "not", "before", "after", "prior", "day", "days", "week", "weeks",
        "medication", "medications", "medicine", "medicines", "directions", "discharge", "visit", "follow",
        "test", "testing", "blood", "pain", "oil", "water", "food", "continue", "hold", "only", "needed",
        "next", "plan", "personal", "regular", "baby", "important", "note", "knee", "hip", "spine",
        "shoulder", "right", "left", "replacement", "admission", "consult", "mrn", "dob", "page",
    ]

    // a dose like 5 mg or 2 tablets
    static let dosePattern = "\\b\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|g|ml|units?|tablets?|tabs?|capsules?|caps?|puffs?|drops?|iu|%)(?![a-z])"

    // words on a line that is about a medicine
    static let medicineVerbs = "\\b(stop|take|hold|continue|medication|medicine|tablet|pill)"

    // a line with a dose or that says stop take or hold
    static func isMedicineLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.range(of: dosePattern, options: .regularExpression) != nil
            || lower.range(of: medicineVerbs, options: .regularExpression) != nil
    }

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
