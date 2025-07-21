//
//  ScanView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//

import SwiftUI
import PhotosUI

struct ScanView: View {
    // MARK: – Image source selection
    @EnvironmentObject private var historyVM: HistoryViewModel
    @State private var activeSheet: ActiveSheet? = .none
    @State private var selectedItem: PhotosPickerItem?
    
    // MARK: – Analysis state
    @State private var isAnalyzing  = false
    @State private var currentPhase = ScanPhase.vision
    
    // MARK: – Pet safety toggles
    @AppStorage("includeDogSafety") private var includeDog = false
    @AppStorage("includeCatSafety") private var includeCat = false
    @State private var showPetOptions = false
    
    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // … inside your ScrollView → VStack(spacing: 24) …

                    // MARK: — Big Gradient Scan Logo
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "viewfinder")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)

                    // MARK: — Title & Subtitle
                    Text("SafeSnap")
                        .font(.largeTitle.bold())
                    Text("AI-powered product safety analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // MARK: Active Badge
                    Label("Google Vision Active", systemImage: "eye")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                    
                    // MARK: Category Pills
                    WrapPillsView(pills: PillData.default)
                    .padding(.horizontal)
                    
                    // MARK: Scan Button
                    Button {
                        activeSheet = .camera
                    } label: {
                        Label("Scan Product", systemImage: "camera")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images, preferredItemEncoding: .automatic, label: {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    })
                    .onChange(of: selectedItem) { item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self),
                               let ui   = UIImage(data: data) {
                                handleImage(ui)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Text("Take a photo or choose from your photo gallery")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    // MARK: Pet Safety Accordion
                    VStack(spacing: 0) {
                        Button {
                            withAnimation { showPetOptions.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill").foregroundColor(.pink)
                                Text("Pet Safety Analysis")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: showPetOptions ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                        if showPetOptions {
                            VStack(spacing: 16) {
                                Toggle(isOn: $includeDog) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Dog Safety")
                                            Text("Include dog safety warnings")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: "pawprint.fill").foregroundColor(.orange)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .orange))
                                
                                Toggle(isOn: $includeCat) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Cat Safety")
                                            Text("Include cat safety warnings")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: "pawprint.fill").foregroundColor(.purple)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                
                                // Info box
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "info.circle")
                                        Text("How it works").font(.subheadline.bold())
                                    }
                                    Text("When enabled, pet safety warnings will be included in the overall safety score. This helps identify products that may be harmful to your pets.")
                                        .font(.caption)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            
            // MARK: Loading Overlay
            if isAnalyzing {
                ScanProgressView(phase: currentPhase)
            }
        }
        // MARK: Sheet for camera/gallery flow
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraView(onImageCaptured: handleImage)
            }
        }
    }
    
    // MARK: – Handle any picked image
    private func handleImage(_ image: UIImage) {
      activeSheet = nil
      isAnalyzing = true

      RecognitionCoordinator.analyze(
        image: image,
        onPhaseChange: { phase in currentPhase = phase },
        completion: { result in
          // back on main
          isAnalyzing = false

          if let r = result {
            // 1️⃣ Add to history
            let historyItem = ScanHistoryItem(
              product: r.product,
              labels: r.labels,
              score: Int(r.score),
              thumbnail: image
            )
            historyVM.add(historyItem)

            // 2️⃣ Show your ResultView (existing flow)
//            self.lastLabels = r.labels
//            self.result     = r.product
//            self.showResult = true
          } else {
            // existing “not found” path
//            self.notFoundLabel = result?.labels.first
//            self.showNotFound  = true
          }
        }
      )
    }
}

// MARK: – Sheet cases
private enum ActiveSheet: Identifiable {
    case camera
    var id: Int { hashValue }
}

// MARK: – Pill helper
private struct Pill: View {
    let icon: String, title: String
    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(title)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
