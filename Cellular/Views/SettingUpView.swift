//
//  SettingUpView.swift
//  Cellular
//
//  Created by Xuan Han on 23/6/23.
//

import SwiftUI

struct SettingUpView: View {
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
        }.padding(.all, 30)
    }
}

struct SettingUpView_Previews: PreviewProvider {
    static var previews: some View {
        SettingUpView()
    }
}
