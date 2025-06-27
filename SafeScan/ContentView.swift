//
//  ContentView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 26/06/2025.
//

import SwiftUI

struct ContentView: View {
//    var body: some View {
//        VStack {
//            Text("SafeScan MVP")
//                .font(.largeTitle)
//                .padding()
//
//            Button("Test Analyzer") {
//                if let product = SafetyAnalyzer.shared.analyze(productName: "Fresh Broccoli") {
//                    print("Found product: \(product.name)")
//                    print("Safety Score: \(product.safetyScore)")
//                } else {
//                    print("❌ Product not found")
//                }
//            }
//        }
//    }
    var body: some View {
        CameraView()
    }
}

#Preview {
    ContentView()
}
