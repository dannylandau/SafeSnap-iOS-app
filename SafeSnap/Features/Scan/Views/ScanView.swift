//
//  ScanView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 27/06/2025.
//

import SwiftUI
import PhotosUI

struct ScanView: View {
    // removed EnvironmentObject; not needed anymore
    @StateObject private var viewModel: ScanViewModel
    @StateObject private var coordinator = ScanAnalysisCoordinator()
    @AppStorage("includeDogSafety") private var includeDog = false
    @AppStorage("includeCatSafety") private var includeCat = false
    @State private var activeSheet: ActiveSheet? = nil
    @State private var showPetOptions = false

    init(viewModel: ScanViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    scanLogo
                    scanTitles
                    scanStatusBadge
                    scanCategoryPills
                    scanActions
                    scanPhotoPicker
                    scanInstructions
                    petSafetyAccordion
                }
            }
        }
        // Camera Sheet
        .sheet(item: $activeSheet) { sheet in
            if case .camera = sheet {
                CameraView(onImageCaptured: viewModel.handleImage)
            }
        }
        .sheet(isPresented: .constant(isShowingAnalysis)) {
            if case let .analyzing(image) = viewModel.phase {
                AnalysisInProgressView(image: image, coordinator: coordinator)
            }
        }
        .sheet(item: $viewModel.resultVM, onDismiss: {
            viewModel.resultVM = nil
            viewModel.phase = .idle
        }) { vm in
            ResultView(vm: vm)
        }
        .task(id: viewModel.phase) {
            if case .analyzing = viewModel.phase {
                await coordinator.start()
                await viewModel.completeAnalysis()
            }
        }
    }

    private var isShowingAnalysis: Bool {
        if case .analyzing = viewModel.phase { return true }
        return false
    }

    private var scanLogo: some View {
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
    }

    private var scanTitles: some View {
        VStack(spacing: 4) {
            Text("SafeSnap").font(.largeTitle.bold())
            Text("AI-powered product safety analysis")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var scanStatusBadge: some View {
        Label("Google Vision Active", systemImage: "eye")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.15))
            .foregroundColor(.green)
            .clipShape(Capsule())
    }

    private var scanCategoryPills: some View {
        WrapPillsView(pills: PillData.default).padding(.horizontal)
    }

    private var scanActions: some View {
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
    }

    private var scanPhotoPicker: some View {
        PhotosPicker(
            selection: $viewModel.selectedItem,
            matching: .images,
            preferredItemEncoding: .automatic
        ) {
            Label("Choose from Photos", systemImage: "photo.on.rectangle.angled")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
        .padding(.horizontal)
    }

    private var scanInstructions: some View {
        Text("Take a photo or choose from your photo gallery")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
    }

    private var petSafetyAccordion: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation { showPetOptions.toggle() }
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill").foregroundColor(.pink)
                    Text("Pet Safety Analysis").font(.headline)
                    Spacer()
                    Image(systemName: showPetOptions ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            if showPetOptions {
                PetOptionsView(includeDog: $includeDog, includeCat: $includeCat)
            }
        }
        .padding(.bottom, 40)
    }
}

private struct PetOptionsView: View {
    @Binding var includeDog: Bool
    @Binding var includeCat: Bool

    var body: some View {
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

private enum ActiveSheet: Identifiable {
    case camera
    var id: Int { hashValue }
}
