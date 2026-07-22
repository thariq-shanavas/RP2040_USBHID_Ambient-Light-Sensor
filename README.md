# RP2040 USB HID Ambient Light Sensor

Build a **plug-and-play USB Ambient Light Sensor (ALS)** with a Raspberry Pi RP2040 board.
<p align="center">
<img src="Images/sensor-2.jpg" alt="Sensor Example 2" width="400" />
</p align="center">
This project helps your computer automatically adjust the brightness of external monitors* based on ambient lighting. It works with either:

- [Clight](https://github.com/FedeDP/Clight) on Linux,
- the included `auto_brightness.sh` script, or
- some Linux desktop environments that have native ALS sensor support (though this capability is only just becoming mature as of 2026)

This is an **open hardware** project, intended for makers who are comfortable with some basic electronics. You will need a Raspberry Pi Pico development board. You will need to do some soldering and simple wiring.

\* DDC/CI-capable monitors - practically all HDMI and DisplayPort monitors

### Why USB HID

This sensor implements the **USB HID (Human Interface Device)** standard. As operating systems already know how to talk to HID devices, this sensor is plug-and-play and requires no additional drivers. It is detected automatically on Linux, Windows, and macOS, making it compatible with standard automatic brightness software.

### Overview
[Requirements](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#requirements)\
[Quick-start](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#instructions)\
[Setting up Clight](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#clight-instructions)\
[Setting up auto-brightness script](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#using-the-auto_brightness-script)\
[Building (For developers)](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#building)\
[How to contribute](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#help-wanted)\
[USB HID basics](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#advanced-internals-and-notes)\
[AI usage policy](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#ai-usage-policy)\
[Acknowledgements](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor#acknowledgements)

### Requirements

- Raspberry Pi RP2040 microcontroller board. 
I recommend a [Waveshare RP2040-Zero](https://www.waveshare.com/rp2040-zero.htm) but really, any RP2040 board you can get hold of, for example the Raspberry Pi Pico.
<p align="center">
<img src="Images/rp2040-zero.png" alt="RP 2040-Zero Board" width="150" />
</p align="center">

- TEMT6000 Light Sensor in a breakout board. Widely available from retail sources, including SparkFun and eBay.
<p align="center">
<img src="Images/temt6000-1.jpg" alt="TEMT6000 Sensor Example 1" width="150" />&nbsp;<img src="Images/temt6000-2.jpg" alt="TEMT6000 Sensor Example 2" width="150" />
</p align="center">

- Soldering iron and headers.

### Instructions

1. Solder the TEMT6000 to the RP2040 board. The Signal goes to pin 26, ground to 27 and Vcc to 28. If you are using the RP2040-Zero or Pi Pico boards, proceed to step 2.
   - If you have a board where pins 26, 27 and 28 are not adjacent, you will either have to do a more elaborate wiring, or edit `main.c` with the GPIO pin numbers you use and compile the firmware following the instructions in the next section. 
   - Please note that the Signal pin has to be connected to the chip's ADC, which can only read from GPIO pins 26, 27, 28 or 29.
   - **Important Note: The TEMT6000 sensor recommends an operating voltage of up to 5V, but you should supply at most 3.3 V to Vcc. This is because the ADC of the RP2040 is referenced to 3.3 V, and a higher voltage might damage the chip.**
   - Tidbit: Since the sensor draws at most about 0.5 mA, it is safe to power it from a GPIO Pin.
<p align="center">
<img src="Images/sensor-1.jpg" alt="Sensor Example 1" width="200" /> <img src="Images/sensor-2.jpg" alt="Sensor Example 2" width="200" />
</p align="center">

2. While holding the bootsel button on the RP2040-Zero board, connect it to your PC. The device should appear as a USB mass storage device. Drag and drop the .uf2 file from the [github releases](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor/releases) to the mass storage device. If the device doesn't automatically reboot, simply unplug and re-plug it again.

3. You can check the live sensor readings via `cat /sys/bus/iio/devices/iio\:device0/in_illuminance_raw`. Without a case, the bare sensor tops out at about 660 Lux. Which isn't very much, but it's more than plenty for meaningful automatic brightness adjustment.

4. That's it, you're done! You may now set up [Clight](https://github.com/FedeDP/Clight) for automatic brightness adjustment, or use the auto-brightness bash script in this repo.

### Clight Instructions

You can launch Clight from the command line using the `-d "iio:device0" ` flag to test if your monitor responds correctly to changing brightness. If you're happy, you may make the changes permanent by editing `/etc/clight/modules.conf.d/sensor.conf`.

Please note that while clight uses a good default curve, you may need to adjust the `ac_regression_points` to calibrate the brightness to your preferences.

Clight scales raw lux readings to between 0 and 1 based on human brightness perception [here](https://github.com/FedeDP/Clightd/blob/ffb5213f1a9b5b045396832a4c8c93fd45c55167/src/modules/sensors/als.h#L12). 

```bash
$ sudo nano /etc/clight/modules.conf.d/sensor.conf
sensor:
{
   # Calibration Curve - Change as needed
   ac_regression_points = [ 0.0, 0.15, 0.29, 0.45, 0.61, 0.74, 0.81, 0.88, 0.93, 0.97, 1.0 ];
   devname = "iio:device0";
};
```

### Using the `auto_brightness` Script

As an alternative to clight, you can run the provided `auto_brightness.sh` script as a background service using `systemd`. Below are the typical steps to install and enable it system-wide. Please note that this script has not been tested as widely as Clight, and may not work with all configurations and monitors. If your desktop environment is Plasma, the KDE version of the script plays nice with the brightness widget in Plasma 6 and above.

Test and tune the script for your setup:

1. Install dependencies, make the script executable, and copy it to a location in your home directory:

```bash
sudo apt install ddcutil
chmod +x auto_brightness_ddcutil.sh
chmod +x auto_brightness_KDE.sh   # If you are using KDE
mkdir -p ~/.local/bin
cp auto_brightness_ddcutil.sh ~/.local/bin/auto_brightness.sh

# Only if you are using KDE
cp auto_brightness_KDE.sh ~/.local/bin/auto_brightness.sh
```

2. Edit `auto_brightness.sh` environmental variables:
```bash
nano ~/.local/bin/auto_brightness.sh
```
   - `SENSOR_PATH` (e.g. `/sys/bus/iio/devices/iio:device0/in_illuminance_raw`)
   - `LUX_MAX` (sensor lux mapping to 100% brightness)
   - `BRIGHTNESS_MIN` / `BRIGHTNESS_MAX` (target output range)
   - `BRIGHTNESS_THRESHOLD` (hysteresis for stability)
   - `INTERVAL` (poll interval in seconds)
3. Run the script manually in a terminal to verify behavior:

```bash
~/.local/bin/auto_brightness.sh
```

4. Observe output and adjust `LUX_MAX` until the automatic brightness matches your preferences. When satisfied, proceed with creating the systemd unit as described below.

5. Create the user systemd unit file `~/.config/systemd/user/auto-brightness.service` with the following contents:

```ini
[Unit]
Description=Auto Brightness using IIO light sensor
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/auto_brightness.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
```

6. Reload user-level systemd, enable and start the service:

```bash
systemctl --user daemon-reload
systemctl --user enable --now auto-brightness.service
systemctl --user status auto-brightness.service
```

7. To stop or disable the service:

```bash
systemctl --user stop auto-brightness.service
systemctl --user disable auto-brightness.service
```


### Building

You only need to follow this section if you are a developer or otherwise seeking to modify the firmware. For using the sensor, please download the pre-compiled firmware from [github releases](https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor/releases) and follow the instructions in the previous section.

**Option A: Build Script**

1. ```bash
   sudo apt update
   sudo apt install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential
   git clone https://github.com/thariq-shanavas/RP2040_USBHID_Ambient-Light-Sensor
   cd RP2040_USBHID_Ambient-Light-Sensor
   ./build.sh
   ```

**Option B: Manual Build**

1. Install the Pico SDK:
   ```bash
   git clone https://github.com/raspberrypi/pico-sdk.git
   cd pico-sdk
   git submodule update --init
   export PICO_SDK_PATH=/path/to/pico-sdk
   ```

2. Install build tools:
   ```bash
   sudo apt update
   sudo apt install cmake gcc-arm-none-eabi libnewlib-arm-none-eabi build-essential
   ```

3. Compile

   ```bash
   mkdir build
   cd build
   cmake ..
   make -j4
   ```


### Help Wanted

There are some yaks in need of shaving. If you have the time, expertise, and resources, I'd sincerely appreciate your help here.

1. There is currently a factor of 3 disagreement between the sensor reading (calibrated from the TEMT6000 datasheet) and what the Lux meter on my phone says. I'm inclined to believe the datasheet, but if you have access to a real lux meter, I'd appreciate some calibration data.

2. It would be nice to have a 3D printed enclosure for ease of handling. If you have the abiliy to make some STL files I'll be glad to inclde them in this repo.

## Advanced Internals and Notes

A [USB HID device](https://learn.adafruit.com/customizing-usb-devices-in-circuitpython/hid-devices) announces its capabilities to your PC using an [HID descriptor](https://eleccelerator.com/tutorial-about-usb-hid-report-descriptors/). However, HID descriptors are fairly challenging to write manually. [Waratah](https://github.com/microsoft/hidtools) is a tool from Microsoft that can convert a high-level description of the reports to an HID descriptor. The HID descriptor for this project was generated using `als_hid_sensor.wara`, included in this repository.

Depending on the type of sensor you are building, it may be improtant to include feature reports in your HID descriptor. An ALS sensor, for instance, requires the following reports:
- Input Reports: Illuminance, Sensor Event
- Feature Reports: Reporting State, Power State and Report Interval

If you do not include all the required reports, the operating system will fail to enumerate the device properly. For reference, see the official [documentation](https://www.usb.org/sites/default/files/hut1_4.pdf) for the HID standard. I could not find a good reference for which reports are absolutely necessary for each sensor type, so I determined the required reports using some trial and error.

I initially started this project in CircuitPython, but soon ran into limitations on CircuitPython's ability to handle feature reports.

CircuitPython's HID implementation uses a polling-based buffer system. It stores incoming feature reports (SET_REPORT requests from the host) in memory buffers that must be checked repeatedly by the program. You can only queue one outgoing (device to host) report at a time, and there doesn't appear to be a way to check if the data in the buffer has been read by the host.

When the host computer (the PC) requested a feature report using GET_REPORT, CircuitPython would send the buffered report. However, if the host issued a second GET_REPORT request before I had a chance to refill that buffer with fresh data, CircuitPython would return whatever garbage data happened to be in memory at that location. This resulted in an unreliable communication between the sensor and the host.

While there might be workarounds to handle CircuitPython's buffered approach, I found it more straightforward to switch to TinyUSB instead.

TinyUSB uses an interrupt-driven architecture. Instead of the program constantly checking buffers for new requests, TinyUSB relies on hardware interrupts. When the host requests a report, the hardware immediately triggers an interrupt that pauses normal program execution and handles the request right away. This approach ensures that every request is serviced immediately with current data, eliminating the possibility of returning stale or garbage values.

Nevetheless, building an HID device using CircuitPython has been an invaluable teaching tool. I decided to include my CircuitPython code in this repository to document the journey.

## AI Usage Policy

Some boilerplate code has been generated with the help of large language models. In particular:

- The HID descriptor, and `als_hid_sensor.wara` was written carefully by consulting the USB HID spec, without any AI assistance.
- The CircuitPython implementation does not include any LLM-generated code.
- The C implementation mostly follows the CircuitPython code. Some parts have been translated using an LLM, and the key differences (eg., interrupt handling) were written by hand.
- The `auto-brightness.sh` script was mostly LLM generated.

Every line of code generated by an LLM has been reviewed by the author.

## Acknowledgements

Many thanks to the wonderful folks who built CircuitPython, Clight and TinyUSB.
