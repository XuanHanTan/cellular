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
                    List(selection: $selectedNetworkIndex) {
                        ForEach(Array(trustedNetworks.enumerated()), id: \.offset) { index, network in
                            if isAdding && index == trustedNetworks.count - 1 {
                                TextField("Network name", text: $trustedNetworks[index]) {
                                    selectedNetworkIndex = nil
                                    isAdding = false
                                    isTextFieldFocused = false
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
                                    .tag(index)
                            }
                        }
                    }.frame(minHeight: 100)
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
                        Button {
                            if selectedNetworkIndex != nil {
                                isAdding = false
                                isTextFieldFocused = false
                                DispatchQueue.main.async {
                                    trustedNetworks.remove(at: selectedNetworkIndex!)
                                    selectedNetworkIndex = nil
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedNetworkIndex == nil)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(.vertical)
        .frame(minWidth: 500, idealWidth: 600, maxWidth: 700,
               minHeight: 300, idealHeight: 400, maxHeight: 500)
    }
}
