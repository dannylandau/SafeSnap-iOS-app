//
//  RecallRecord.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import Foundation

struct RecallRecord: Decodable, Identifiable {
    var id: String { recallNumber }
    let recallNumber: String
    let productName: String
    let description: String
    let recallDate: String
    let url: String
}

class RecallService {
    static func fetchRecalls(for productName: String, completion: @escaping ([RecallRecord]) -> Void) {
        let baseURL = "https://www.saferproducts.gov/RestWebServices/Recall"
        let params = "?format=json&RecallDateStart=2020-01-01"

        guard let url = URL(string: baseURL + params) else {
            completion([])
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data else {
                completion([])
                return
            }

            do {
                let allRecalls = try JSONDecoder().decode([RecallRecord].self, from: data)
                // Match by simple name check (improve later)
                let filtered = allRecalls.filter {
                    $0.productName.lowercased().contains(productName.lowercased())
                }
                DispatchQueue.main.async {
                    completion(filtered)
                }
            } catch {
                print("Recall parsing failed: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }.resume()
    }
}