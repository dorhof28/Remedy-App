//
//  MedicineText.swift
//  Remedy
//
//  medicine names doses and times as readable text
//

import Foundation

enum MedicineText {

    
    // name people know like advil
    static func everydayName(_ medicine: MedicineInstruction) -> String {
        if medicine.isGroup { return medicine.name }
        let own = medicine.name.lowercased()
        let brand = medicine.alsoKnownAs.map { $0.lowercased() }.first { (name: String) -> Bool in
            name != own && !own.contains(name)
        }
        guard let brand = brand else { return medicine.name }
        return "\(medicine.name) (\(brand.capitalized))"
    }

    // name with other names in brackets
    static func fullName(_ medicine: MedicineInstruction) -> String {
        if medicine.strength.isEmpty || medicine.name.contains(medicine.strength) {
            return medicine.name
        }
        return "\(medicine.name) \(medicine.strength)"
    }

    // amount and food note
    static func howText(_ medicine: MedicineInstruction) -> String {
        let parts = [medicine.amount, medicine.foodNote].filter { (part: String) -> Bool in !part.isEmpty }
        return parts.joined(separator: " · ")
    }

    // dose times as text
    static func timesText(_ medicine: MedicineInstruction) -> String {
        let times = medicine.timesOfDay.map { (minute: Int) -> String in DayMath.shortTimeText(minute) }
        return times.joined(separator: " · ")
    }
}
