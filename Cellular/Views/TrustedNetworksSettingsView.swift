//
//  TrustedNetworksSettingsView.swift
//  Cellular
//
//  Created by Xuan Han on 4/8/23.
//

import SwiftUI

struct TrustedNetworksSettingsView: View {
    @Binding var path: NavigationPath
    @AppStorage("useTrustedNetworks") private var useTrustedNetworks = true
    @State private var trustedNetworkSSIDs: [String] = []
    @State private var selectedNetworkIndex: Int?
    @State private var isAdding = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var tempAddText = ""
    
    let defaults = UserDefaults.standard
    
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
    
    func onSubmitNetworkName() {
        isTextFieldFocused = false
        selectedNetworkIndex = nil
        isAdding = false
        
        if tempAddText != "" && tempAddText != wlanModel.ssid && !trustedNetworkSSIDs.contains(tempAddText) {
            trustedNetworkSSIDs.append(tempAddText)
            tempAddText = ""
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
                        Text("Allow your Mac to switch from your phone's hotspot to your trusted networks automatically when they are available. Network names and passwords are stored locally on your Mac.")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .onChange(of: useTrustedNetworks) { newValue in
                        if !newValue {
                            onSubmitNetworkName()
                        }
                    }
                    List(selection: $selectedNetworkIndex) {
                        ForEach(Array(trustedNetworkSSIDs.enumerated()), id: \.offset) { index, network in
                            Text(network)
                                .foregroundColor(useTrustedNetworks ? .none : .gray)
                                .tag(index)
                        }
                        if isAdding {
                            TextField("Network name", text: $tempAddText)
                                .focused($isTextFieldFocused)
                                .onSubmit(onSubmitNetworkName)
                                .submitScope()
                                .tag(-1)
                        }
                    }
                    .frame(minHeight: 100)
                    .overlay {
                        if useTrustedNetworks && !isAdding && trustedNetworkSSIDs.isEmpty {
                            Text("No trusted networks added.\nClick Add (+) to add a network.")
                                .multilineTextAlignment(.center)
                        }
                    }
                    .disabled(!useTrustedNetworks)
                    HStack(spacing: 10) {
                        Button {
                            if !isAdding {
                                selectedNetworkIndex = -1
                                isAdding = true
                                tempAddText = ""
                                isTextFieldFocused = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 13, height: 13)
                        }
                        .buttonStyle(.borderless)
                        .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                        Button {
                            let prevSelectedNetworkIndex = selectedNetworkIndex!
                            selectedNetworkIndex = nil
                            isTextFieldFocused = false
                            isAdding = false
                            tempAddText = ""
                            if prevSelectedNetworkIndex != -1 {
                                trustedNetworkSSIDs.remove(at: prevSelectedNetworkIndex)
                            }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 13, height: 13)
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
        .onAppear {
            trustedNetworkSSIDs = defaults.stringArray(forKey: "trustedNetworks") ?? []
        }
        .onChange(of: trustedNetworkSSIDs) { newValue in
            defaults.set(trustedNetworkSSIDs, forKey: "trustedNetworks")
        }
    }
}
