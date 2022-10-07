# NES for Analogue Pocket

Ported from the core originally developed by [Ludvig Strigeus](https://github.com/strigeus/fpganes) and heavily developed by [@sorgelig](https://github.com/sorgelig), [@greyrogue](https://github.com/greyrogue), [@Kitrinx](https://github.com/Kitrinx), [@paulb-nl](https://github.com/paulb-nl), and many more. Core icon by [spiritualized1997](https://github.com/spiritualized1997). Latest upstream available at https://github.com/MiSTer-devel/NES_MiSTer

Please report any issues encountered to this repo. Most likely any problems are a result of my port, not the original core. Issues will be upstreamed as necessary.

## Installation

### Easy mode

I highly recommend the updater tools by [@mattpannella](https://github.com/mattpannella) and [@RetroDriven](https://github.com/RetroDriven). If you're running Windows, use [the RetroDriven GUI](https://github.com/RetroDriven/Pocket_Updater), or if you prefer the CLI, use [the mattpannella tool](https://github.com/mattpannella/pocket_core_autoupdate_net). Either of these will allow you to automatically download and install openFPGA cores onto your Analogue Pocket. Go donate to them if you can

### Manual mode
To install the core, copy the `Assets`, `Cores`, and `Platform` folders over to the root of your SD card. Please note that Finder on macOS automatically _replaces_ folders, rather than merging them like Windows does, so you have to manually merge the folders.

## Usage

ROMs should be placed in `/Assets/nes/common`

PAL ROMs should boot, but there may be timing and sound issues as the core currently doesn't properly support PAL (proper support coming soon). I highly recommend you do not play PAL games at this time

## Features

### Dock Support

Core supports four players/controllers via the Analogue Dock. To enable four player mode, turn on `Use Multitap` setting.

### Saves

Supports saves for most games and mappers. Saving on the NES is rather complicated due to the different scenarios for different mappers, so it's possible some less common mappers do not save correctly on this core. Please report all such issues to this repo

### Expansion Audio

Expansion audio should be fully supported. If you encounter a game that is not playing the expanded audio, please report it.

### Palette Options

The core has 5 palette options built in, changable in `Core Settings`. The palettes are known as:

* Kitrinx 34 by Kitrinx
* Smooth by FirebrandX (Default)
* Wavebeam by NakedArthur
* Sony CXA by FirebrandX
* PC-10 Better by Kitrinx

### Video Options

There are several options provided for tweaking the displayed video:

* `Hide Overscan` - Hides the top and bottom 8 pixels of the video, which would normally be masked by the CRT. Adjusts the aspect ratio to correspond with this modification
* `Edge Masking` - Masks the sides of the screen in black, depending on the chosen option. The auto setting automatically masks the left side when certain conditions are met.
* `Extra Sprites` - Allows an extra 8 sprites to be displayed per line (up to 16 from the original 8). Will decrease flickering in some games

### Lightguns

Core supports virtual lightguns by enabling the "Use Zapper" setting. The crosshair can be controlled with the D-Pad or left joystick, using the A button to fire. D-Pad aim sensitivity can be adjusted with the "D-Pad Aim Speed" setting.

**NOTE:** Joystick support for aiming only appears to work when a controller is paired over Bluetooth and not connected to the Analogue Dock directly by USB.
