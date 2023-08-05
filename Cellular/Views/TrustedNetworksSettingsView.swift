//
//  TrustedNetworksSettingsView.swift
//  Cellular
//
//  Created by Xuan Han on 4/8/23.
//

import SwiftUI

struct TrustedNetworksSettingsView: View {
    @Binding var path: NavigationPath
    @AppStorage("useTrustedNetworks") var useTrustedNetworks = true
    @State private var trustedNetworks: [String] = []
    @State private var selectedNetworkIndex: Int?
    @State private var isAdding = false
    @FocusState private var isTextFieldFocused: Bool
    
    struct BackButtonStyle: ButtonStyle {
        @State private var isOverButton = false
        
        func makeBody(configuration: Self.Configuration) -> some View {
            configuration.label
                .foregroundColor(configuration.isPressed ? Color.white: Color.gray)
                .frame(width: 28, height: 28)
                .background(configuration.isPressed ? Color(NSColor.darkGray).opacity(0.5): self.isOverButton ? Color(NSColor.darkGray).opacity(0.3) : Color.clear)
                .onHover { hover in
                    self.isOverButton = hover
                }
                .cornerRadius(6.0)
                .animation(.default, value: self.isOverButton)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    path.removeLast()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                }
                .buttonStyle(BackButtonStyle())
                Text("Trusted networks")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            Form {
                Section {
                    Toggle(isOn: $useTrustedNetworks) {
                        Text("Trusted networks")
                        Text("Allow your Mac to switch from your phone's hotspot to your trusted networks automatically when they are available.")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .onChange(of: useTrustedNetworks) { newValue in
                        if !newValue {
                            selectedNetworkIndex = nil
                            isTextFieldFocused = false
                            isAdding = false
                            DispatchQueue.main.async {
                                if trustedNetworks.last == "" {
                                    trustedNetworks.removeLast()
                                }
                            }
                        }
                    }
                    List(selection: $selectedNetworkIndex) {
                        ForEach(Array(trustedNetworks.enumerated()), id: \.offset) { index, network in
                            if isAdding && index == trustedNetworks.count - 1 {
                                TextField("Network name", text: $trustedNetworks[index]) {
                                    isTextFieldFocused = false
                                    selectedNetworkIndex = nil
                                    isAdding = false
                                    DispatchQueue.main.async {
                                        if trustedNetworks[index] == "" {
                                            trustedNetworks.removeLast()
                                        } else {
                                            // Store new network name in UserDefaults
                                        }
                                    }
                                }
                                .focused($isTextFieldFocused)
                                .submitScope()
                                .tag(index)
                            } else {
                                Text(network)
                                    .foregroundColor(useTrustedNetworks ? .none : .gray)
                                    .tag(index)
                            }
                        }
                    }
                    .frame(minHeight: 100)
                    .overlay {
                        if useTrustedNetworks && trustedNetworks.isEmpty {
                            Text("No trusted networks added.\nClick Add (+) to add a network.")
                                .multilineTextAlignment(.center)
                        }
                    }
                    .disabled(!useTrustedNetworks)
                    HStack(spacing: 10) {
                        Button {
                            if !isAdding {
                                trustedNetworks.append("")
                                selectedNetworkIndex = trustedNetworks.count - 1
                                isAdding = true
                                isTextFieldFocused = true
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                        .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                        Button {
                            if selectedNetworkIndex != nil {
                                let prevSelectedNetworkIndex = selectedNetworkIndex!
                                selectedNetworkIndex = nil
                                isTextFieldFocused = false
                                isAdding = false
                                DispatchQueue.main.async {
                                    trustedNetworks.remove(at: prevSelectedNetworkIndex)
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedNetworkIndex == nil)
                        .keyboardShortcut(KeyEquivalent.delete, modifiers: [])
                    }
                    .disabled(!useTrustedNetworks)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.vertical)
        .frame(width: 600, height: 400)
    }
}
