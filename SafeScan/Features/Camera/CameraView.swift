//
//  CameraView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//


import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var showResult = false
    @State private var result: Product?
    @State private var notFoundLabel: String? = nil
    @State private var showNotFound = false
    @State private var isLoading = false
    @AppStorage("scanHistory") private var scanHistoryData: Data = Data()
    @State private var scanHistory: [ScanHistoryItem] = []

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Button(action: {
                    viewModel.capturePhoto()
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .shadow(radius: 10)
                }
                .padding()
            }
            
            if isLoading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("Analyzing...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            if let decoded = try? JSONDecoder().decode([ScanHistoryItem].self, from: scanHistoryData) {
                scanHistory = decoded
            }
        }
        .onChange(of: viewModel.capturedImage) { image in
            guard let image else { return }
            isLoading = true

            VisionService.recognizeLabels(from: image) { labels in
                isLoading = false
                print("🔍 Labels:", labels)

                if let topLabel = labels.first,
                   let product = SafetyAnalyzer.shared.analyze(productName: topLabel) {
                    withAnimation {
                        result = product
                        showResult = true
                    }
                    
                    let newItem = ScanHistoryItem(name: product.name, score: product.safetyScore)

                    scanHistory.insert(newItem, at: 0)
                    scanHistory = Array(scanHistory.prefix(3))

                    if let encoded = try? JSONEncoder().encode(scanHistory) {
                        scanHistoryData = encoded
                    }
                    
                } else {
                    withAnimation {
                        notFoundLabel = labels.first
                        showNotFound = true
                    }
                }
            }
        }
        .sheet(isPresented: $showResult) {
            if let product = result {
                ResultView(product: product)
            }
        }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: showResult)
        .sheet(isPresented: $showNotFound) {
            NotFoundView(productName: notFoundLabel)
        }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: showResult)
    }
}
