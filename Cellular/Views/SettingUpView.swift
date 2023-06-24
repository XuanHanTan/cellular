//
//  SettingUpView.swift
//  Cellular
//
//  Created by Xuan Han on 23/6/23.
//

import SwiftUI

struct SettingUpView: View {
    let handleNextScreen: () -> Void
    
    @ObservedObject var bluetoothModel: BluetoothModel
    
    var body: some View {
        VStack {
            Text("Setting things up")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
            Spacer()
            ProgressView().scaleEffect(0.5)
            Text("Receiving hotspot details...")
            Spacer()
        }.padding(.all, 30).onChange(of: bluetoothModel.isSetupComplete) { newValue in
            if newValue {
                handleNextScreen()
            }
        }
    }
}

struct SettingUpView_Previews: PreviewProvider {
    static var previews: some View {
        SettingUpView(handleNextScreen: {}, bluetoothModel: BluetoothModel())
    }
}
