//
//  DownloadAppView.swift
//  Cellular
//
//  Created by Xuan Han on 11/6/23.
//

import SwiftUI

struct DownloadAppView: View {
    @Environment(\.openURL) private var openURL
    
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Install the Cellular Companion app")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Image(nsImage: NSImage(named: "AppIcon")!)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .padding(.bottom, 5)
                Button {
                    let url = URL(string: "https://play.google.com/store/apps/details?id=com.xuanhan.cellularcompanion")!
                    openURL(url)
                } label: {
                    Image("play_badge")
                        .resizable()
                        .frame(width: 207, height: 80)
                }
                .padding(.bottom, 20)
                .buttonStyle(.plain)
                Text("The Cellular Companion app will help your Mac connect to your Android device and control its mobile hotspot settings. Click the button above to open the Google Play Store.\n\n\nAlternatively, open this link on your phone:")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                Text("https://xuanhan.me/short/cellular-companion")
                    .font(.title3)
                    .fontWeight(.bold)
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
