//
//  FinishSetupView.swift
//  Cellular
//
//  Created by Xuan Han on 24/6/23.
//

import SwiftUI

struct FinishSetupView: View {
    let handlePreferencesButton: () -> Void
    let handleFinishButton: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Setup is complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Image("companion_icon")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .padding(.bottom, 40)
                Text("Thank you for your purchase!\nSee device information and configure your settings by opening the Cellular menu bar extension.")
                    .multilineTextAlignment(.center)
                Spacer()
            }.padding(.all, 30)
            Divider()
            HStack {
                Spacer()
                Button("Settings", action: handlePreferencesButton)
                    .controlSize(.large)
                    .padding(.trailing, 5)
                Button("Finish", action: handleFinishButton)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }.padding(.all, 15)
        }
    }
}

struct FinishSetupView_Previews: PreviewProvider {
    static var previews: some View {
        FinishSetupView(handlePreferencesButton: {}, handleFinishButton: {})
    }
}
