//
//  ConnectView.swift
//  Nothing X MacOS
//
//  Created by Arunavo Ray on 14/02/23.
//

import SwiftUI

struct ConnectView: View {
    
    @State var title: String? = "Failed to connect"
    @State var text: String? = "Make sure device is on and in discovery mode."
    @State var topButtonText: String? = "Retry"
    @State var bottomButtonText: String? = "Cancel"
    
    @StateObject private var viewModel = ConnectViewViewModel(bluetoothService: BluetoothServiceImpl())
    
    @EnvironmentObject var mainViewModel: MainViewViewModel
    
    var body: some View {
        
        
        ZStack(alignment: .bottom) {
            
            
            // ear (1)
            
            if mainViewModel.selectedDevice?.isHeadphonePro != true {
                HStack {
                    DeviceNameDotTextView()
                    Spacer()
                }
                .padding(.bottom, 4)
                .zIndex(1)
            }
            
            
            
            VStack {
                
                HStack {
                    if mainViewModel.selectedDevice?.isHeadphonePro == true {
                        Text("CMF Headphone Pro").font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                            .padding(.leading, 14)
                    }
                    Spacer()
                    // Settings
                    SettingsButtonView()
                    
                    // Quit
                    QuitButtonView()
                }
                
                VStack {
                    // Ear 1 Image
                    if mainViewModel.selectedDevice?.isHeadphonePro == true {
                        Image("cmf_headphone_pro")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .accessibilityLabel("CMF Headphone Pro")
                    } else {
                    Image("ear_1")
                        .overlay(
                            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                                .blendMode(SwiftUI.BlendMode.darken) // Blend mode to darken the image
                        )
                    
                    
                    }
                    Spacer(minLength: 15)
                    
                    if mainViewModel.isConnecting {
                        // Show loading spinner
                        ProgressView() // You can customize the text
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(Color.white)
                            .colorInvert()
                            .scaleEffect(0.6)
                        
                        
                    } else {
                        // Connect Button
                        Button("RECONNECT") {
                            viewModel.checkBluetoothStatus()
                            if viewModel.isBluetoothOn {
                                mainViewModel.reconnectSelectedDevice()
                            } else {
                                mainViewModel.navigateToBluetoothIsOff()
                            }
                        
                        }
                        .buttonStyle(OffWhiteConnectButton())
                        .focusable(false)
                        
                        
                    }
                    Spacer(minLength: 15)
                }
                
                
            }
            
            // Bottom sheet overlay
            if viewModel.isFailedToConnectPresented {
                Color.black.opacity(0.4) // Background dimming
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            viewModel.isFailedToConnectPresented = false
                        }
                    }
                    .zIndex(2)
                
                ModalSheetView(isPresented: $viewModel.isFailedToConnectPresented, title: $title, text: $text, topButtonText: $topButtonText, bottomButtonText: $bottomButtonText, action: {
                    viewModel.isFailedToConnectPresented = false
                    mainViewModel.reconnectSelectedDevice()
                }, onCancelAction: {})
                .animation(.easeInOut, value: viewModel.isFailedToConnectPresented) // Animate the appearance
                .offset(y: viewModel.isFailedToConnectPresented ? 0 : 180) // Slide in from the bottom
                .zIndex(3)
                
            }
            
        }
        
        .padding(.bottom, 0)
        .background(.black)
        .frame(width: mainViewModel.selectedDevice?.isHeadphonePro == true ? 280 : 250, height: mainViewModel.selectedDevice?.isHeadphonePro == true ? 340 : 230)
        .navigationBarBackButtonHidden(true)
        
    }
        
        
        
}


struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView()
    }
}
