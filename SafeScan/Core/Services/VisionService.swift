//
//  VisionService.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import UIKit

struct VisionService {
    static func recognizeLabels(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let apiKey = Bundle.main.infoDictionaryValue(for: "GoogleVisionAPIKey"),
              let base64Image = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() else {
            completion([])
            return
        }

        let url = URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "requests": [[
                "image": ["content": base64Image],
                "features": [["type": "LABEL_DETECTION", "maxResults": 5]]
            ]]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard
                error == nil,
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let responses = json["responses"] as? [[String: Any]],
                let labels = responses.first?["labelAnnotations"] as? [[String: Any]]
            else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let descriptions = labels.compactMap { $0["description"] as? String }
            DispatchQueue.main.async {
                completion(descriptions)
            }
        }.resume()
    }
}

extension Bundle {
    func infoDictionaryValue(for key: String) -> String? {
        guard let path = path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) else { return nil }
        return dict[key] as? String
    }
}
