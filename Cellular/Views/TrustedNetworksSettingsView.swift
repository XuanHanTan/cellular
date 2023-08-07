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
    @State private var trustedNetworkPasswords: [String] = []
    @State private var selectedNetworkIndex: Int?
    @State private var isAdding = false
    @State private var tempAddName = ""
    @State private var tempAddPassword = ""
    
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
                            selectedNetworkIndex = nil
                            isAdding = false
                        }
                    }
                    List(selection: $selectedNetworkIndex) {
                        ForEach(Array(trustedNetworkSSIDs.enumerated()), id: \.offset) { index, network in
                            Text(network)
                                .foregroundColor(useTrustedNetworks ? .none : .gray)
                                .tag(index)
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
                                selectedNetworkIndex = nil
                                isAdding = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 13, height: 13)
                        }
                        .sheet(isPresented: $isAdding, content: {
                            VStack(spacing: 0) {
                                VStack(spacing: 5) {
                                    Text("Add trusted network")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Network names and passwords are stored locally on your Mac.")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Form {
                                        Section {
                                            TextField("Name:", text: $tempAddName)
                                            SecureField("Password:", text: $tempAddPassword)
                                                .focusable(true)
                                        }
                                    }
                                    .padding(.top, 15)
                                    .padding(.bottom, 10)
                                }
                                .padding(.all, 20)
                                Divider()
                                HStack(spacing: 10) {
                                    Spacer()
                                    Button("Cancel") {
                                        isAdding = false
                                        tempAddName = ""
                                        tempAddPassword = ""
                                    }
                                    .keyboardShortcut(.cancelAction)
                                    Button("Add") {
                                        selectedNetworkIndex = nil
                                        isAdding = false
                                        
                                        if tempAddName != "" && tempAddName != wlanModel.ssid && !trustedNetworkSSIDs.contains(tempAddName) {
                                            trustedNetworkSSIDs.append(tempAddName)
                                            trustedNetworkPasswords.append(tempAddPassword)
                                            tempAddName = ""
                                            tempAddPassword = ""
                                        }
                                    }
                                    .keyboardShortcut(.defaultAction)
                                }.padding(.all, 20)
                            }
                            .frame(width: 400, alignment: .leading)
                        })
                        .buttonStyle(.borderless)
                        .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                        Button {
                            let prevSelectedNetworkIndex = selectedNetworkIndex!
                            selectedNetworkIndex = nil
                            isAdding = false
                            if prevSelectedNetworkIndex != -1 {
                                trustedNetworkSSIDs.remove(at: prevSelectedNetworkIndex)
                                trustedNetworkPasswords.remove(at: prevSelectedNetworkIndex)
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
            trustedNetworkPasswords = defaults.stringArray(forKey: "trustedNetworkPasswords") ?? []
        }
        .onChange(of: trustedNetworkSSIDs) { newValue in
            defaults.set(trustedNetworkSSIDs, forKey: "trustedNetworks")
            defaults.set(trustedNetworkPasswords, forKey: "trustedNetworkPasswords")
        }
    }
}
