//
//  TrustedNetworksListView.swift
//  Cellular
//
//  Created by Xuan Han on 19/8/23.
//

import SwiftUI

struct TrustedNetworksListView: View {
    @Binding var useTrustedNetworks: Bool
    
    @State private var trustedNetworkSSIDs: [String] = []
    @State private var trustedNetworkPasswords: [String] = []
    @State private var selectedNetworkIndex: Int?
    @State private var isAdding = false
    @State private var tempAddName = ""
    @State private var tempAddPassword = ""
    
    let defaults = UserDefaults.standard
    
    var body: some View {
        Section {
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
                            Text("Network names and passwords are stored locally on your Mac. Your phone's hotspot name must not be set as a trusted network.")
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
                                
                                trustedNetworkSSIDs.append(tempAddName)
                                trustedNetworkPasswords.append(tempAddPassword)
                                tempAddName = ""
                                tempAddPassword = ""
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(tempAddName == "" || tempAddName == wlanModel.ssid || trustedNetworkSSIDs.contains(tempAddName))
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
        .onAppear {
            trustedNetworkSSIDs = defaults.stringArray(forKey: "trustedNetworks") ?? []
            trustedNetworkPasswords = defaults.stringArray(forKey: "trustedNetworkPasswords") ?? []
        }
        .onChange(of: trustedNetworkSSIDs) { newValue in
            defaults.set(trustedNetworkSSIDs, forKey: "trustedNetworks")
            defaults.set(trustedNetworkPasswords, forKey: "trustedNetworkPasswords")
        }
        .onChange(of: useTrustedNetworks) { newValue in
            if !newValue {
                selectedNetworkIndex = nil
                isAdding = false
            }
        }
    }
}

struct TrustedNetworksListView_Previews: PreviewProvider {
    static var previews: some View {
        TrustedNetworksListView(useTrustedNetworks: .constant(true))
    }
}
