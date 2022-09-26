# NES for Analogue Pocket

Ported from the core originally developed by [Ludvig Strigeus](https://github.com/strigeus/fpganes) and heavily developed by [@sorgelig](https://github.com/sorgelig), [@greyrogue](https://github.com/greyrogue), [@Kitrinx](https://github.com/Kitrinx), [@paulb-nl](https://github.com/paulb-nl), and many more.

Please report any issues encountered to this repo. Most likely any problems are a result of my port, not the original core. Issues will be upstreamed as necessary.

## Usage

ROMs should be placed in `/Assets/nes/common`

PAL ROMs should boot, but there may be timing and sound issues as the core currently doesn't properly support PAL (proper support coming soon). I highly recommend you do not play PAL games at this time

## Features

### Dock Support

Core supports four players/controllers via the Analogue Dock. To enable four player mode, turn on `Use Multitap` setting.

### Saves

Supports saves for most games and mappers. Saving on the NES is rather complicated due to the different scenarios for different mappers, so it's possible some less common mappers do not save correctly on this core. Please report all such issues to this repo

### Palette Options

The core has 5 palette options built in, changable with a slider in `Core Settings`. The palettes are known as:

0. Kitrinx 34 by Kitrinx
1. Smooth by FirebrandX (Default)
2. Wavebeam by NakedArthur
3. Sony CXA by FirebrandX
4. PC-10 Better by Kitrinx

### Video Options

There are several options provided for tweaking the displayed video:

* `Hide Overscan` - Hides the top and bottom 8 pixels of the video, which would normally be masked by the CRT. Adjusts the aspect ratio to correspond with this modification
* `Edge Masking` - Masks the sides of the screen in black, depending on the chosen option. The auto setting automatically masks the left side when certain conditions are met.
* `Extra Sprites` - Allows an extra 8 sprites to be displayed per line (up to 16 from the original 8). Will decrease flickering in some games