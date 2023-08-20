//
//  QRCodeView.swift
//  Cellular
//
//  Created by Xuan Han on 12/6/23.
//

import SwiftUI

struct QRCodeView: View {
    @Binding var path: NavigationPath
    
    @State private var qrCodeNSImage: NSImage?
    @StateObject private var bluetoothModel = Cellular.bluetoothModel
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Scan this QR code when prompted to")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)
                Spacer()
                VStack {
                    if qrCodeNSImage != nil && bluetoothModel.isPoweredOn {
                        Image(nsImage: qrCodeNSImage!)
                            .resizable()
                            .frame(width: 256, height: 256)
                            .cornerRadius(6)
                    } else {
                        ZStack {
                            ProgressView()
                        }
                        .frame(width: 256, height: 256)
                    }
                }.padding(.bottom, 40)
                Text("This QR code contains information to help your Mac securely pair with and receive information from your Android device over Bluetooth. Continue setup on your Android device after scanning the QR code.")
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
                Spacer()
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Waiting for device to connect...")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 20)
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
            }
            .padding(.all, 15)
        }
        .frame(width: 900, height: 650, alignment: .center)
        .onAppear {
            do {
                let qrCodeData = try JSONSerialization.data(withJSONObject: bluetoothModel.prepareForNewConnection())
                
                let filter = CIFilter(name: "CIQRCodeGenerator")!
                let data = qrCodeData
                filter.setValue(data, forKey: "inputMessage")
                let CIImage = filter.outputImage!
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledCIImage = CIImage.transformed(by: transform)
                let representation = NSCIImageRep(ciImage: scaledCIImage)
                
                qrCodeNSImage = NSImage(size: representation.size)
                qrCodeNSImage!.addRepresentation(representation)
            } catch {
                print(error.localizedDescription)
            }
        }
        .onChange(of: bluetoothModel.isHelloWorldReceived) { newValue in
            if newValue {
                DispatchQueue.main.async {
                    path.append("settingUpView")
                }
            }
        }
    }
}

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView(path: .constant(NavigationPath()))
    }
}
