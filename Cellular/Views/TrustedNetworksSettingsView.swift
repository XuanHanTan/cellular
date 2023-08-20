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
                    TrustedNetworksListView(useTrustedNetworks: $useTrustedNetworks)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.vertical)
        .frame(width: 650, height: 400)
    }
}
