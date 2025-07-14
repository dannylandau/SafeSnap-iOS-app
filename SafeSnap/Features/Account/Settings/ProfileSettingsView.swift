//
//  ProfileSettingsView.swift
//  SafeScan
//
//  Created by Marcin Grześkowiak on 10/07/2025.
//


import SwiftUI

struct ProfileSettingsView: View {
    @AppStorage("userName") private var userName: String = "Maria Garcia"
    @AppStorage("userEmail") private var userEmail: String = "maria.garcia@email.com"

    @State private var draftName: String = ""
    @State private var buttonPressed = false
    @State private var showToast = false

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("Name", text: $draftName)
                    .textContentType(.name)
                    .autocapitalization(.words)
            }

            Section(header: Text("Email"), footer:  Text("Email cannot be changed")) {
                VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: .constant(userEmail))
                            .disabled(true)
                            .foregroundColor(.gray)
                    }
            }

            Section {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonPressed = true
                        userName = draftName
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showToast = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        buttonPressed = false
                    }
                }) {
                    Text("Save Changes")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(12)
                        .scaleEffect(buttonPressed ? 0.95 : 1.0)
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            draftName = userName
        }
        
        if showToast {
            VStack {
                Spacer()
                ToastView(message: "Changes saved")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .animation(.easeOut, value: showToast)
        }
    }
    
}

#Preview {
    NavigationView {
        ProfileSettingsView()
    }
}
