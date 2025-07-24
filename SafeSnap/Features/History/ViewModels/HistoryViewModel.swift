//
//  HistoryViewModel.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//

import Foundation
import Combine

@MainActor
final class HistoryViewModel: ObservableObject {
    // Published property for view consumption
    @Published private(set) var records: [ScanHistoryItem] = []

    // Private
    private let service: ScanHistoryService
    private var cancellables = Set<AnyCancellable>()

    init(service: ScanHistoryService) {
        self.service = service
        self.records = service.records

        // React to updates in the service
        service.$records
            .receive(on: RunLoop.main)
            .assign(to: &$records)
    }

    func add(_ item: ScanHistoryItem) {
        service.add(item)
    }

    func delete(at offsets: IndexSet) {
        service.delete(at: offsets)
    }

    // Optional for future logic: grouping, filtering, stats
    func scansGroupedByDate() -> [Date: [ScanHistoryItem]] {
        Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.date) }
    }
}
