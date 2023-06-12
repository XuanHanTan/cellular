//
//  StartView.swift
//  Cellular
//
//  Created by Xuan Han on 11/6/23.
//

import SwiftUI

struct StartView: View {
    @Environment(\.colorScheme) var colorScheme
    let handleNextButton: () -> Void
    
    var body: some View {
        VStack{
            Spacer()
            Image(colorScheme == .dark ? "start_vector_night": "start_vector_day")
                .resizable()
                .frame(width: 484, height: 352)
                .padding(.bottom, 20)
            Text("Welcome to Cellular!")
                .font(.largeTitle)
                .fontWeight(.bold).padding(.bottom, 20)
            Text("Connect to your Android device’s mobile hotspot seamlessly, as if your Mac has cellular data.")
                .padding(.bottom, 10)
            Spacer()
            Button("Get started", action: handleNextButton)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.bottom, 20)
        }.padding(.all)
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView {}
    }
}
