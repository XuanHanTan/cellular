//
//  SettingUpView.swift
//  Cellular
//
//  Created by Xuan Han on 23/6/23.
//

import SwiftUI

struct SettingUpView: View {
    @Binding var path: NavigationPath
    
    @StateObject private var bluetoothModel = Cellular.bluetoothModel
    
    var body: some View {
        VStack {
            Text("Setting things up")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
            Spacer()
            ProgressView()
                .scaleEffect(0.5)
            Text("Receiving hotspot details...")
            Spacer()
        }
        .padding(.all, 30)
        .frame(width: 900, height: 650, alignment: .center)
        .onChange(of: bluetoothModel.isSetupComplete) { newValue in
            if newValue {
                DispatchQueue.main.async {
                    path.append("trustedNetworksSetupView")
                }
            }
        }
    }
}

struct SettingUpView_Previews: PreviewProvider {
    static var previews: some View {
        SettingUpView(path: .constant(NavigationPath()))
    }
}
