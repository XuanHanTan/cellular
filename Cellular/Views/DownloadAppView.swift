//
//  DownloadAppView.swift
//  Cellular
//
//  Created by Xuan Han on 11/6/23.
//

import SwiftUI

struct DownloadAppView: View {
    @Binding var path: NavigationPath
    
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
            }
            .padding(.all, 30)
            Divider()
            HStack {
                Spacer()
                Button("Back") {
                    path.removeLast()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .padding(.trailing, 5)
                NavigationLink(value: "qrCodeView") {
                    Text("Continue")
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.all, 15)
        }
        .frame(width: 900, height: 650, alignment: .center)
    }
}

struct DownloadAppView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadAppView(path: .constant(NavigationPath()))
    }
}
