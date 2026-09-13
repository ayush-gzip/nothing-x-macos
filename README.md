# Nothing X for macOS

An unofficial menu bar app for Nothing Ear (1) and CMF Headphone Pro. View battery levels and change noise control and EQ settings from your Mac.

This project is in early development and is not affiliated with Nothing.

## Device support

| Device | Status |
| --- | --- |
| Nothing Ear (1) | Tested by the original developers. |
| CMF Headphone Pro | Device communication tested on firmware `1.0.1.49`. |
| Other models | Not verified. |

### Nothing Ear (1) features

The original Ear (1) interface remains available: left and right battery levels, noise control, EQ, earbud controls, in-ear detection, low lag mode, and Find My Earbuds. Select a saved Ear (1) from **Devices** to show its controls.

### CMF Headphone Pro features

- Battery level and charging status.
- ANC: Low, Medium, High, and Adaptive.
- Ambient sound and noise control Off.
- EQ: Balanced, More bass, More treble, and Voice.
- Device name, serial number, and firmware version.
- Nothing menu bar logo with battery percentage.
- Automatic reconnect when macOS connects the selected saved device.

**Not implemented for this model:** earbud gestures, advanced settings, custom EQ, genre presets, sound calibration, and firmware updates. An unsupported EQ preset is not shown as Balanced.

## Get started

Requirements: macOS 13 or later and Xcode to build the app.

1. Open `Nothing X MacOS.xcodeproj` in Xcode. Select the **Nothing X MacOS** scheme, then build and run it.
2. Pair the headphones with your Mac in Bluetooth settings.
3. Open the app from the menu bar. Use discovery to select and set up your device.
4. Use **Devices → Set up another device** to add another device. Use **Devices** to select any saved device. The app remembers your selection.

For CMF Headphone Pro, keep the Bluetooth name **CMF Headphone Pro**. The app cannot select between multiple connected headphones with that name.

After setup, the app reconnects its control service when macOS reports a new connection for the selected saved device. **Opening the app does not start a connection.** If the device was already connected, select it from **Devices** or select **Reconnect**.

The selector changes the app control connection. It does not change the macOS audio output. **Forget this device** removes only the selected device.

## Development

CMF Headphone Pro uses the native Bluetooth Low Energy `FD90` control service. The local test device advertised RFCOMM channel 17, but that connection did not complete; BLE did.

### Read-only device check

Connect CMF Headphone Pro to your Mac, then run:

```sh
./scripts/check-headphone.sh
```

Requires Xcode or the Swift command-line tools. The check reads firmware, serial number, battery, ANC, and EQ through the app service. It closes only its BLE control connection and does not save app settings or close the audio connection.

### Validation

- App build and eight focused checks passed, including saved selection, switching, retry, and deletion.
- Earlier live device reads and all noise control modes passed; ANC High was restored.
- Earlier Balanced and More bass EQ changes were read back and restored.
- The updated headphone panel was rendered and visually checked.
- A native macOS reconnect event opened the control service; startup did not.
- Neither device was connected for a live selector test. Ear (1) hardware was not available.
- Menu bar appearance in macOS still needs a manual check.

## Screenshots

<details>
<summary>Ear (1) interface</summary>

These screenshots show the original Ear (1) interface.

![Ear (1) home screen](assets/NothingX.png)
![Equaliser](assets/Equaliser.png)
![Earbud controls](assets/Controls.png)
![Find My Buds](assets/FindMyBuds.png)

</details>

## Credits

- [Arunavo Ray](https://github.com/arunavo4/nothing-x-macos) — original app and interface.
- Daniel — upstream fork development.
- [swift-nothing-ear contributors](https://github.com/bestK1ngArthur/swift-nothing-ear) — CMF Headphone Pro protocol references.
- [Ear (web)](https://earweb.bttl.xyz) — Bluetooth communication references.
- [Nothing](https://in.nothing.tech/products/cmf-headphone-pro/) — product artwork and dot logo assets.

## License and legal notice

See [LICENSE](LICENSE) for the GNU General Public License v3.0. The original project's legal notice is retained below.

<details>
<summary>Original legal notice</summary>

The program and its corresponding code are distributed under the provisions of the GNU General Public License v3.0. (LICENSE)

Any entities, including Nothing Technology Limited and its associated organizations, are legally licensed to use this application for all intents and purposes, encompassing commercial usage, devoid of any obligation to remunerate the software creator. Abidance by the GNU General Public License v3.0 is not mandated for Nothing Technology.

This application has been crafted by Daniel (forked from Arunavo), and does not possess any association with, sponsorship from, or endorsement by Nothing Technology. The application's creator, Arunavo, bears no liability for the correctness or comprehensiveness of the materials and content delivered via this application. The elements incorporated within this application, such as text, graphics, logos, imagery, and audio-visual resources, are the exclusive property of Nothing Technology Limited, located at 80 Cheapside, London EC2V 6EE, and are safeguarded by copyright, trademark, and other intellectual property legislations. The use of these resources is prohibited without the explicit written consent of Nothing Technology. All rights pertaining to these resources are retained by Nothing Technology.

</details>
