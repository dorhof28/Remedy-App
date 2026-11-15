//
//  AddressCompleter.swift
//  Remedy
//
//  live address and hospital suggestions from MapKit, no key and no location permission
//

import Foundation
import MapKit
import Observation

// one address suggestion
struct PlaceSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion?

    static func == (a: PlaceSuggestion, b: PlaceSuggestion) -> Bool { a.id == b.id }
}

// live address and hospital suggestions as the patient types
@MainActor @Observable
final class AddressCompleter: NSObject, MKLocalSearchCompleterDelegate {

    private(set) var suggestions: [PlaceSuggestion] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var search: MKLocalSearch?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // hospitals first when the name fits
        completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hospital])
    }

    // waits for a pause in typing, then asks
    func update(_ text: String, hospitals: Bool) {
        pending?.cancel()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3 else {
            suggestions = []
            return
        }
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            completer.resultTypes = hospitals ? [.pointOfInterest, .address] : [.address, .pointOfInterest]
            completer.pointOfInterestFilter = hospitals ? MKPointOfInterestFilter(including: [.hospital]) : .includingAll
            completer.queryFragment = query
        }
    }

    // on dismiss
    func cancel() {
        pending?.cancel()
        search?.cancel()
        completer.cancel()
        suggestions = []
    }

    // the full name and address for a tapped suggestion, the suggestion's own lines when offline
    func resolve(_ suggestion: PlaceSuggestion) async -> PlaceFill {
        guard let completion = suggestion.completion else {
            return PlaceFill.make(suggestionTitle: suggestion.title, suggestionSubtitle: suggestion.subtitle,
                                  itemName: nil, fullAddress: nil)
        }
        search?.cancel()
        let request = MKLocalSearch.Request(completion: completion)
        let local = MKLocalSearch(request: request)
        search = local
        let item = try? await local.start().mapItems.first
        return PlaceFill.make(suggestionTitle: suggestion.title, suggestionSubtitle: suggestion.subtitle,
                              itemName: item?.name, fullAddress: item?.address?.fullAddress)
    }

    // keeps the first 4 suggestions that have a usable name and address
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let found = completer.results
            .filter { PlaceFill.isUsable(title: $0.title, subtitle: $0.subtitle) }
            .prefix(4)
            .map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0) }
        Task { @MainActor in self.suggestions = Array(found) }
    }

    // offline or no match shows nothing
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}
