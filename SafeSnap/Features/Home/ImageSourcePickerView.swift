//
//  ImageSourcePickerView.swift
//  SafeSnap
//
//  Created by Marcin Grześkowiak on 14/07/2025.
//


import SwiftUI
import PhotosUI

struct ImageSourcePickerView: View {
    /// Callbacks
    var onCamera: () -> Void
    var onGallery: () -> Void
    
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                Text("How would you like to add a photo?")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Camera Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    onCamera()
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Take Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Gallery Button
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    onGallery()
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                        Text("Choose from Gallery")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Add Photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}