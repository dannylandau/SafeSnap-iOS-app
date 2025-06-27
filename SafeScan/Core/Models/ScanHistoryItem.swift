//
//  ScanHistoryItem.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

struct ScanHistoryItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let score: Int
}