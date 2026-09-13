//
//  HomeView.swift
//  Nothing X MacOS
//
//  Created by Arunavo Ray on 14/02/23.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var viewModel: MainViewViewModel
    
    
    var body: some View {
        if viewModel.nothingDevice?.isHeadphonePro == true {
            HeadphoneHomeView(anc: viewModel.headphoneANC, battery: viewModel.leftBattery,
                              isCharging: viewModel.nothingDevice?.isLeftCharging == true,
                              eqReady: viewModel.headphoneEQ != nil) {
                NothingServiceImpl.shared.switchANC(mode: $0)
            }
        } else {
        ZStack {
            
            HStack {
                DeviceNameDotTextView()
                Spacer()
            }
            
            .padding(.bottom, 4)
            .zIndex(1)
       

            VStack(alignment: .center) {
                
                // Settings | Quit
                HStack {
                    Spacer()
                    
                    // Settings
                    SettingsButtonView()
                    
                    // Quit
                    QuitButtonView()
                }
                
                
                VStack {
                    
                    
                    //HStack - Equaliser | Controls
                    HStack(spacing: 5) {
                        

                        //EQUALISER
                         
                        if #available(macOS 14.0, *) {
                            NavigationLink("EQUALISER", value: Destination.equalizer)
                                .buttonStyle(GreyButton())
                                .focusable(false)
                                .focusEffectDisabled()
                        } else {
                            NavigationLink("EQUALISER", value: Destination.equalizer)
                                .buttonStyle(GreyButton())
                                .focusable(false)
                                
                        }
                                
                            
                        //CONTROLS
                        if #available(macOS 14.0, *) {
                            NavigationLink("CONTROLS", value: Destination.controls)
                                .buttonStyle(GreyButton())
                                .focusable(false)
                                .focusEffectDisabled()
                        } else {
                            NavigationLink("CONTROLS", value: Destination.controls)
                                .buttonStyle(GreyButton())
                                .focusable(false)
                                
                        }
                        
                    }
                    
                    Spacer()
                    
                    // NOISE CONTROL
                    if #available(macOS 14.0, *) {
                        NoiseControlView(selection: $store.noiseControlSelected)
                            .focusable(false)
                            .focusEffectDisabled()
                    } else {
                        NoiseControlView(selection: $store.noiseControlSelected)
                            .focusable(false)
                    }
                    
                    Spacer()
                    
                    // Battery Indicator
                    BatteryIndicatorView()
                    Spacer()
                }
                // Compensates for Leading side Spacer + DotTextView
                
                
                
            }
                    
        }
    
        .background(.black)
        .frame(width: 250, height: 230)
        .navigationBarBackButtonHidden(true)
        }
    }
        
}

struct HeadphoneHomeView: View {
    let anc: ANC?
    let battery: Double?
    let isCharging: Bool
    let eqReady: Bool
    let switchANC: (ANC) -> Void
    @State private var cancellationLevel: ANC = .ON_HIGH

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("CMF Headphone Pro")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                SettingsButtonView()
                QuitButtonView()
            }
            Image("cmf_headphone_pro")
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .accessibilityLabel("CMF Headphone Pro")
            NavigationLink("EQUALISER", value: Destination.equalizer)
                .buttonStyle(GreyButton())
                .disabled(!eqReady)
            VStack(spacing: 8) {
                Text("NOISE CONTROL")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    noiseButton("ANC", mode: cancellationLevel, selected: anc?.isCancellation == true)
                    noiseButton("Ambient", mode: .TRANSPARENCY, selected: anc == .TRANSPARENCY)
                    noiseButton("Off", mode: .OFF, selected: anc == .OFF)
                }
                HStack(spacing: 4) {
                    ForEach(ANC.cancellationLevels, id: \.self) { level in
                        noiseButton(level.title, mode: level, selected: anc == level)
                    }
                }
                .disabled(anc?.isCancellation != true)
            }
            .disabled(anc == nil)
            HStack(spacing: 5) {
                Image(systemName: isCharging ? "battery.100percent.bolt" : "battery.100percent")
                if let battery = battery {
                    Text("\(Int(battery))%\(isCharging ? " · Charging" : "")")
                } else {
                    Text("Reading battery…")
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.gray)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .foregroundColor(.white)
        .frame(width: 280, height: 340)
        .background(.black)
        .navigationBarBackButtonHidden(true)
        .onAppear { rememberLevel(anc) }
        .onChange(of: anc) { rememberLevel($0) }
    }

    private func rememberLevel(_ mode: ANC?) {
        if let mode = mode, mode.isCancellation { cancellationLevel = mode }
    }

    private func noiseButton(_ title: String, mode: ANC, selected: Bool) -> some View {
        Button { switchANC(mode) } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundColor(selected ? .black : .white)
                .background(selected ? Color.white : Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(title == "Ambient" || title == "Off" ? title : "Noise cancellation \(title)")
    }
}

struct HomeView_Previews: PreviewProvider {
    static let store = Store()

    @State static var currentDestination: Destination? = .home
    static let viewModel: MainViewViewModel = MainViewViewModel(bluetoothService: BluetoothServiceImpl(), nothingRepository: NothingRepositoryImpl.shared, nothingService: NothingServiceImpl.shared)

    
    static var previews: some View {
            // Use a Group to allow for multiple previews if needed
        
        HomeView() // Pass the binding
                    .environmentObject(store)
                    .environmentObject(viewModel)
                    .previewDisplayName("Home View Preview") // Optional: Name the preview
            
        }

}
