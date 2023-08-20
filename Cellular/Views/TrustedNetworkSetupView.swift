//
//  TrustedNetworkSetupView.swift
//  Cellular
//
//  Created by Xuan Han on 19/8/23.
//

import SwiftUI

struct TrustedNetworkSetupView: View {
    @Binding var path: NavigationPath
    @State var useTrustedNetworks = true
    
    let defaults = UserDefaults.standard
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Add some trusted networks")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 20)
                Text("When you add trusted networks, your Mac can switch from your phone's hotspot to your trusted networks automatically when they are available, saving energy and improving battery life. Network names and passwords are stored locally on your Mac. You can always set this up later in Settings.")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                Form {
                    Section {
                        TrustedNetworksListView(useTrustedNetworks: $useTrustedNetworks, isSetup: true)
                    }
                }
                .frame(width: 500, height: 300)
                Spacer()
            }
            .padding(.all, 30)
            Divider()
            HStack {
                Spacer()
                NavigationLink(value: "finishSetupView") {
                    Text("Continue")
                }
                .simultaneousGesture(TapGesture().onEnded{
                    let trustedNetworks = defaults.stringArray(forKey: "trustedNetworks") ?? []
                    if !trustedNetworks.isEmpty {
                        defaults.set(true, forKey: "useTrustedNetworks")
                    }
                })
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.all, 15)
        }
        .frame(width: 900, height: 650, alignment: .center)
    }
}

struct TrustedNetworkSetupView_Previews: PreviewProvider {
    static var previews: some View {
        TrustedNetworkSetupView(path: .constant(NavigationPath()))
    }
}
