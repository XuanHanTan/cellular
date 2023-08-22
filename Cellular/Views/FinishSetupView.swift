//
//  FinishSetupView.swift
//  Cellular
//
//  Created by Xuan Han on 24/6/23.
//

import SwiftUI
import ServiceManagement

struct FinishSetupView: View {
    @Binding var path: NavigationPath
    
    func finishSetup() {
        // Close setup window
        NSApplication.shared.keyWindow?.close()
        
        // Register login item to auto-start app on startup
        do {
            try SMAppService.loginItem(identifier: "com.xuanhan.cellularhelper").register()
        } catch {
            print("Failed to register login item: \(error.localizedDescription)")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Setup is complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Image("menubar_screenshot")
                    .resizable()
                    .frame(width: 340, height: 300)
                    .cornerRadius(6)
                    .padding(.bottom, 20)
                Text("Thank you for your purchase!\n\nSee device information and configure your settings by opening the Cellular menu.")
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.all, 30)
            Divider()
            HStack {
                Spacer()
                Button("Settings") {
                    finishSetup()
                    
                    // Open settings window
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .controlSize(.large)
                .padding(.trailing, 5)
                Button("Finish") {
                    finishSetup()
                    
                    // Make app an accessory (no icon in Dock)
                    NSApp.setActivationPolicy(.accessory)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.all, 15)
        }
        .frame(width: 900, height: 650, alignment: .center)
    }
}

struct FinishSetupView_Previews: PreviewProvider {
    static var previews: some View {
        FinishSetupView(path: .constant(NavigationPath()))
    }
}
