//
//  DownloadAppView.swift
//  Cellular
//
//  Created by Xuan Han on 11/6/23.
//

import SwiftUI

struct DownloadAppView: View {
    let handleBackButton: () -> Void
    let handleNextButton: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Install the Cellular Companion app")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Image("companion_icon")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .padding(.bottom, 40)
                Text("The Cellular Companion app will help your Mac remain connected to your Android device and control the mobile hotspot settings of your device. It is available on the Google Play Store. Click the Continue button once you have installed the Cellular Companion app.")
                    .multilineTextAlignment(.center)
                Spacer()
            }.padding(.all, 30)
            Divider()
            HStack {
                Spacer()
                Button("Back", action: handleBackButton)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                    .padding(.trailing, 5)
                Button("Continue", action: handleNextButton)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }.padding(.all, 15)
        }
    }
}

struct DownloadAppView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadAppView(handleBackButton: {}, handleNextButton: {})
    }
}
