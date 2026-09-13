//
//  Nothing_X_MacOSApp.swift
//  Nothing X MacOS
//
//  Created by Arunavo Ray on 07/01/23.
//

import SwiftUI


@main
struct Nothing_X_MacOSApp: App {
    @StateObject private var store = Store()
    @StateObject private var viewModel = MainViewViewModel(bluetoothService: BluetoothServiceImpl(), nothingRepository: NothingRepositoryImpl.shared, nothingService: NothingServiceImpl.shared)
    @StateObject private var budsPickerViewModel = BudsPickerComponentViewModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 0) {
                DeviceSelectorView()
                    .frame(height: 36)
                Divider().overlay(Color.white.opacity(0.15))
                NavigationStack(path: $viewModel.navigationPath.animation(.default)) {

                    Group {
                        if viewModel.nothingDevice != nil {
                            HomeView()
                        } else if viewModel.isSettingUpDevice || viewModel.savedDevices.isEmpty {
                            DiscoverView()
                        } else {
                            ConnectView()
                        }
                    }
                        .navigationDestination(for: Destination.self) { destination in
                            switch(destination) {
                            case .home: HomeView()
                                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            case .equalizer: EqualizerView(eqMode: $viewModel.eqProfiles)
                            case .controls: ControlsView()
                            case .controlsTripleTap: ControlsDetailView(destination: .controlsTripleTap, leftTripleTapAction: $viewModel.leftTripleTapAction, rightTripleTapAction: $viewModel.rightTripleTapAction, leftTapAndHoldAction: $viewModel.leftTapAndHoldAction, rightTapAndHoldAction: $viewModel.rightTapAndHoldAction)
                            case .controlsTapHold: ControlsDetailView(destination: .controlsTapHold,
                                                                      leftTripleTapAction: $viewModel.leftTripleTapAction, rightTripleTapAction: $viewModel.rightTripleTapAction, leftTapAndHoldAction: $viewModel.leftTapAndHoldAction, rightTapAndHoldAction: $viewModel.rightTapAndHoldAction
                            )
                            case .settings: SettingsView()
                            case .findMyBuds: FindMyBudsView()
                            case .discover: DiscoverView()
                                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            case .connect: ConnectView()
                                //                                .animation(nil)
                                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                            case .discover_started: DiscoverStartedView()
                            case .bluetooth_off: BluetoothIsOffView()

                            }


                        }

                }
                .id(viewModel.selectedDeviceMAC)
                .frame(width: viewModel.usesHeadphoneLayout ? 280 : 250, height: viewModel.usesHeadphoneLayout ? 340 : 230)
            }
            .background(.black)
            .environmentObject(store)
            .environmentObject(viewModel)
            .environmentObject(budsPickerViewModel)
            .frame(width: viewModel.usesHeadphoneLayout ? 280 : 250)


        } label: {

            HStack(spacing: 5) {
                Image("nothing_logo")
                    .renderingMode(.template)
                if let battery = viewModel.menuBattery {
                    Text("\(Int(battery))%")
                }
            }
            .accessibilityLabel("Nothing X")

        }
        .menuBarExtraStyle(.window)

    }
}

struct DeviceSelectorView: View {
    @EnvironmentObject var viewModel: MainViewViewModel

    var body: some View {
        Menu {
            ForEach(viewModel.savedDevices, id: \.bluetoothDetails.mac) { device in
                Button { viewModel.selectDevice(mac: device.bluetoothDetails.mac) } label: {
                    Label(device.bluetoothDetails.name,
                          systemImage: device.bluetoothDetails.mac == viewModel.selectedDeviceMAC ? "checkmark" : device.isHeadphonePro ? "headphones" : "earbuds")
                }
            }
            if !viewModel.savedDevices.isEmpty { Divider() }
            Button("Set up another device", action: viewModel.startDeviceSetup)
        } label: {
            Text("Devices: \(viewModel.selectedDevice?.bluetoothDetails.name ?? "Choose device")")
                .font(.system(size: 11))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
        }
        .menuStyle(.borderlessButton)
        .disabled(viewModel.isConnecting)
        .accessibilityLabel("Devices")
    }
}
