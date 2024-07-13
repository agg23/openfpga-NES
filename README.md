
# Pocket openFPGA NES Core with support for Analogizer-FPGA adapter
* Analogizer V1.0.0 [30/03/2024]: Initial Analogizer support release
* Analogizer V1.0.1 [13/07/2024]: Added support for Y/C video and Scandoubler RGBHV. The savestate support was removed to make room for Analogizer features.
  
Analogizer support added by RndMnkIII. See more in the Analogizer main repository: [Analogizer](https://github.com/RndMnkIII/Analogizer)

Adapted to Analogizer by [@RndMnkIII](https://github.com/RndMnkIII) based on **agg23** NES for Analogue Pocket:
https://github.com/agg23/openfpga-NES
  
The core can output RGBS, RGsB, YPbPr, Y/C and SVGA scandoubler(0%, 25%, 50% 75% scanlines and HQ2x) video signals.

| Video output | Status |
| :----------- | :----: |
| RGBS         |  ✅    |
| RGsB         |  ✅    |
| YPbPr        |  ✅    |
| Y/C NTSC     |  ✅    |
| Y/C PAL      |  ✅    |
| Scandoubler  |  ✅    |

The Analogizer interface allow to mix game inputs from compatible SNAC gamepads supported by Analogizer (DB15 Neogeo, NES, SNES, PCEngine) with Analogue Pocket built-in controls or from Dock USB or wireless supported controllers (Analogue support).

**Analogizer** is responsible for generating the correct encoded Y/C signals from RGB and outputs to R,G pins of VGA port. Also redirects the CSync to VGA HSync pin.
The required external Y/C adapter that connects to VGA port is responsible for output Svideo o composite video signal using his internal electronics. Oficially
only the Mike Simone Y/C adapters (active) designs will be supported by Analogizer and will be the ones to use.

Support native PCEngine/TurboGrafx-16 2btn, 6 btn gamepads and 5 player multitap using SNAC adapter
and PC Engine cable harness (specific for Analogizer). Many thanks to [Mike Simone](https://github.com/MikeS11/MiSTerFPGA_YC_Encoder) for his great Y/C Encoder project.

For output Y/C and composite video you need to select in Pocket's Menu: `Analogizer Video Out > Y/C NTSC` or `Analogizer Video Out > Y/C NTSC,Pocket OFF`.
For output Scandoubler SVGA video you need to select in Pocket's Menu: `Analogizer Video Out > Scandoubler RGBHV`.

You will need to connect an active VGA to Y/C adapter to the VGA port (the 5V power is provided by VGA pin 9). I'll recomend one of these (active):
* [MiSTerAddons - Active Y/C Adapter](https://misteraddons.com/collections/parts/products/yc-active-encoder-board/)
* [MikeS11 Active VGA to Composite / S-Video](https://ultimatemister.com/product/mikes11-active-composite-svideo/)
* [Active VGA->Composite/S-Video adapter](https://antoniovillena.com/product/mikes1-vga-composite-adapter/)

Using another type of Y/C adapter not tested to be used with Analogizer will not receive official support.
============================================================================================================

Ported from the core originally developed by [Ludvig Strigeus](https://github.com/strigeus/fpganes) and heavily developed by [@sorgelig](https://github.com/sorgelig), [@greyrogue](https://github.com/greyrogue), [@Kitrinx](https://github.com/Kitrinx), [@paulb-nl](https://github.com/paulb-nl), and many more. Core icon by [spiritualized1997](https://github.com/spiritualized1997). Latest upstream available at https://github.com/MiSTer-devel/NES_MiSTer

Please report any issues encountered to this repo. Most likely any problems are a result of my port, not the original core. Issues will be upstreamed as necessary.

## Installation

### Easy mode

I highly recommend the updater tools by [@mattpannella](https://github.com/mattpannella) and [@RetroDriven](https://github.com/RetroDriven). If you're running Windows, use [the RetroDriven GUI](https://github.com/RetroDriven/Pocket_Updater), or if you prefer the CLI, use [the mattpannella tool](https://github.com/mattpannella/pocket_core_autoupdate_net). Either of these will allow you to automatically download and install openFPGA cores onto your Analogue Pocket. Go donate to them if you can

### Manual mode
To install the core, copy the `Assets`, `Cores`, and `Platform` folders over to the root of your SD card. Please note that Finder on macOS automatically _replaces_ folders, rather than merging them like Windows does, so you have to manually merge the folders.

## Usage

ROMs should be placed in `/Assets/nes/common`

PAL ROMs should boot, but there will be timing and sound issues as the core currently doesn't properly support PAL (proper support coming soon). I highly recommend you do not play PAL games, and instead use NTSC games (if they exist) at this time.

## Features

### Dock Support

Core supports four players/controllers via the Analogue Dock. To enable four player mode, turn on `Use Multitap` setting.

### Mappers

This core has pairity with the MiSTer core's mapper support. [See the full breakdown here](https://github.com/MiSTer-devel/NES_MiSTer#supported-mappers). Please note that the VRC7 expansion audio chip is not supported in this core (but is in MiSTer) due to space constraints.

### Save States/Sleep + Wake

Known as "Memories" on the Pocket, this core supports the creation and loading of save states for most mappers. See the full list in the [Mappers section](#mappers). By extension, the core supports Sleep + Wake functionality on the Pocket. In games with supported mappers, tapping the power button while playing will suspend the game, ready to be resumed when powering the Pocket back on.

### Saves

Supports saves for most games and mappers. Saving on the NES is rather complicated due to the different scenarios for different mappers, so it's possible some less common mappers do not save correctly on this core. Please report all such issues to this repo.

### Controller Turbo

By configuring the `Turbo Speed` controller option in `Core Settings`, you can use the `X` and `Y` buttons (by default) as `A`/`B` turbo buttons. The period for each of the settings in NTSC are below (PAL will have different timings):

| Setting | Period |
| ------- | ------ |
| 0       | Off    |
| 1       | 3 Hz   |
| 2       | 5 Hz   |
| 3       | 7.5 Hz |
| 4       | 10 Hz  |
| 5       | 15 Hz  |
| 6       | 30 Hz  |

### Expansion Audio

Expansion audio should be supported for every mapper except those that use VRC7. If you encounter a game that is not playing the expanded audio outside of VRC7, please report it.

### Palette Options

The core has 5 palette options built in, changable in `Core Settings/Palette`. The palettes are known as:

* Kitrinx 34 by Kitrinx
* Smooth by FirebrandX (Default)
* Wavebeam by NakedArthur
* Sony CXA by FirebrandX
* PC-10 Better by Kitrinx

You can load external palettes as well. This palette is stored at `Assets/nes/agg23.NES/custom.pal`, and can be selected by the sixth option (`Custom`).

For testing, or to temporarily load a new palette, you can choose the `Load Custom Palette` option (make sure to choose `Core Settings/Palette/Custom`). This palette selection is temporary, and will be reset when quitting and reopening the core.

### Video Options

There are several options provided for tweaking the displayed video:

* `Hide Overscan` - Hides the top and bottom 8 pixels of the video, which would normally be masked by the CRT. Adjusts the aspect ratio to correspond with this modification. This option does nothing in PAL mode
* `Edge Masking` - Masks the sides of the screen in black, depending on the chosen option. The auto setting automatically masks the left side when certain conditions are met.
* `Square Pixels` - The internal resolution of the NES is a 8:7 pixel aspect ratio (wide pixels), which roughly corresponds to what users would see on 4:3 display aspect ratio CRTs. Some games are designed to be displayed at 8:7 PAR (the core's default), and others at 1:1 PAR (square pixels). The `Square Pixels` option is provided to switch to a 1:1 pixel aspect ratio.
* `Extra Sprites` - Allows an extra 8 sprites to be displayed per line (up to 16 from the original 8). Will decrease flickering in some games

### Lightguns

Core supports virtual lightguns by enabling the "Use Zapper" setting. The crosshair can be controlled with the D-Pad or left joystick, using the A button to fire. D-Pad aim sensitivity can be adjusted with the "D-Pad Aim Speed" setting.

**NOTE:** Joystick support for aiming only appears to work when a controller is paired over Bluetooth and not connected to the Analogue Dock directly by USB.
