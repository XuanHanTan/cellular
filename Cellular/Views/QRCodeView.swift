//
//  QRCodeView.swift
//  Cellular
//
//  Created by Xuan Han on 12/6/23.
//

import SwiftUI

struct QRCodeView: View {
    let handleBackButton: () -> Void
    
    @State private var qrCodeNSImage: NSImage?
    @ObservedObject var bluetoothModel: BluetoothModel
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Text("Scan this QR code when prompted to")
                    .font(.largeTitle)
                    .fontWeight(.bold)
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
                        }.frame(width: 256, height: 256)
                    }
                }.padding(.bottom, 40)
                Text("This QR code contains information to help your Mac securely pair with and receive information from your Android device over Bluetooth.")
                    .multilineTextAlignment(.center)
                Spacer()
            }.padding(.all, 30)
            Divider()
            HStack {
                Spacer()
                Button("Back", action: handleBackButton)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
            }.padding(.all, 15)
        }.onAppear {
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
        }.onDisappear {
            bluetoothModel.disposeBluetooth()
        }
    }
}

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView(handleBackButton: {}, bluetoothModel: BluetoothModel())
    }
}
