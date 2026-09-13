# Nothing X MacOS [Unofficial]

This is an unofficial companion app for Nothing Ear (1) and CMF Headphone Pro on macOS. The Nothing X iOS app inspired it.

> Note: The app is under early development. Ear (1) was tested by the original developers. CMF Headphone Pro device communication was tested locally on firmware 1.0.1.49. Other models are not verified.

## CMF Headphone Pro

The app uses the native Bluetooth Low Energy FD90 control service. The headphones on the test Mac advertised RFCOMM channel 17, but that connection did not complete. BLE connected and returned device data.

Implemented:
- One headphone battery level and charging status.
- Device name, serial number, and firmware version.
- Noise control: ANC Low, Medium, High, and Adaptive; Ambient and Off.
- EQ presets: Balanced, More bass, More treble, and Voice.
- CMF Headphone Pro artwork and a Nothing logo with one battery value in the menu bar.
- Automatic control connection when macOS reports that the saved headphones connected. Opening the app does not initiate a connection; use Reconnect if they were already connected before app startup.

The app hides earbud gesture controls and advanced settings for this model. Custom EQ, genre presets, sound calibration, and firmware updates are not implemented. Presets that the app cannot display do not appear as Balanced.

Keep the Bluetooth name `CMF Headphone Pro` for model detection. This connection path selects one connected headphone with that name; it does not select between several headphones with the same name.

### Device check

With CMF Headphone Pro connected to the Mac, run:

```sh
./scripts/check-headphone.sh
```

This read-only check uses the app's Bluetooth manager and service. It reads firmware, serial number, battery, ANC, and EQ. It closes its BLE control connection after the check. It does not close the headphone audio connection or save app settings. Xcode or the Swift command-line tools are required.

### Local validation

- App build and four focused tests: passed.
- Live device reads through the app service: passed.
- ANC Low, Medium, High, Adaptive, Ambient, and Off: read back successfully. ANC High was restored.
- EQ Balanced and More bass changes: previously read back successfully and restored.
- Updated headphone panel: rendered and visually checked.
- Native macOS connection event: tested without an app-start connection.
- Menu bar appearance in macOS still requires a manual visual check.

The product artwork and Nothing dot logo use assets from [Nothing’s product page](https://in.nothing.tech/products/cmf-headphone-pro/).

Special credits to:

> swift-nothing-ear contributors for CMF Headphone Pro protocol references.
Link: https://github.com/bestK1ngArthur/swift-nothing-ear


> Ear (web) project developers for bluetooth communication code, it has been really helpful in developing of Nothing X Mac. 
Link to Ear (web): https://earweb.bttl.xyz

> Arunavo Ray. The user interface of Nothing X Mac is based on his original work.
Link to original repository: https://github.com/arunavo4/nothing-x-macos?ysclid=m7w2denfko175827967


## UI Screenshots

<table>
  <tr>
  <td><img src="assets/NothingX.png" alt="NothingX"></td>
    <td><img src="assets/Equaliser.png" alt="Equaliser"></td>
  </tr>
  <tr>
    <td><img src="assets/Controls.png" alt="Controls"></td>
    <td><img src="assets/FindMyBuds.png" alt="FindMyBuds"></td>
  </tr>
</table>

## LEGAL

The program and its corresponding code are distributed under the provisions of the GNU General Public License v3.0. (LICENSE)

Any entities, including Nothing Technology Limited and its associated organizations, are legally licensed to use this application for all intents and purposes, encompassing commercial usage, devoid of any obligation to remunerate the software creator. Abidance by the GNU General Public License v3.0 is not mandated for Nothing Technology.

This application has been crafted by Daniel (forked from Arunavo), and does not possess any association with, sponsorship from, or endorsement by Nothing Technology. The application's creator, Arunavo, bears no liability for the correctness or comprehensiveness of the materials and content delivered via this application. The elements incorporated within this application, such as text, graphics, logos, imagery, and audio-visual resources, are the exclusive property of Nothing Technology Limited, located at 80 Cheapside, London EC2V 6EE, and are safeguarded by copyright, trademark, and other intellectual property legislations. The use of these resources is prohibited without the explicit written consent of Nothing Technology. All rights pertaining to these resources are retained by Nothing Technology.
