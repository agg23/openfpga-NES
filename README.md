
# Pocket openFPGA NES Core with support for Analogizer-FPGA adapter
* Analogizer V1.0.0 [30/03/2024]: Initial Analogizer support release
* Analogizer V1.0.1 [13/07/2024]: Added support for Y/C video and Scandoubler RGBHV. The savestate support was removed to make room for Analogizer features.
* Analogizer V1.0.2 [12/02/2025]: Added support for Analogizer configuration file, PSX SNAC gamecontrollers and NES SNAC Zapper lightgun.
* * Analogizer V1.0.3 [27/02/2025]: Using customized Chip32 loader code the core recovers the savestate support.
This method divides the core in two bitstreams each one with a specific support for mappers. The Chip32 loader
check the NES ROM header al calculates the mapper code and load the bistream with the required mapper. This
reduces the logic resources required (divides the mapper code into two blocks). Thanks to @agg23 by his help.
This is based in the method used by @agg23 for the openFPGA SNES core.


Tested NES SNAC adapters working with the Zapper lightgun:
* https://ultimatemister.com/product/ultimate-snac-mini-hdmi/
* Blue212 based design (uses two board, a common board and console specific connector board).  https://manuferhi.com/p/snac-adapter-for-mister with the [two port NES](https://www.etsy.com/de-en/listing/1556489601/mister-fpga-snac-adapter-nes-2p) connector or [one port](https://www.etsy.com/de-en/listing/1781156747/mister-snac-adapter-nes-vertical). Any SNAC adapter based on Blue212 design will be work.

Recomended settings inside Pupdate (PocketSetup>Analogizer Config>Standard Analogizer Config) for use the NES Zapper lightgun with a NES SNAC adapter:
```
SNAC Controller:     NES - Nintendo Entertainment System gamepad
SNAC Assigments:     SNAC P1,P2 -> Pocket P1,P2                 
```

Recomended settings with NES Core Pocket menu  for use the NES Zapper lightgun with a NES SNAC adapter:
```
Use Zapper > SNAC Zapper
```

Connect the Zapper to the second port of the NES SNAC adapter (if you have the two ports version) or to the first port (if you have the one port version).

For use with PSX Analog stick emulating the reticle lightgun. Use this settings inside Pupdate (PocketSetup>Analogizer Config>Standard Analogizer Config):
```
SNAC Controller:     PSX (Analog PAD) - PlayStation 1/2 analog gamepad
SNAC Assigments:     SNAC P1,P2 -> Pocket P1,P2                       
```

Recomended settings with NES Core Pocket menu  for use the NES Zapper lightgun with a NES SNAC adapter:
```
Use Zapper > Emulated Zapper (Stick)
```

Use the PSX game controller connected to the first port of th PSX SNAC adapter.
  
Analogizer support added by RndMnkIII. See more in the Analogizer main repository: [Analogizer](https://github.com/RndMnkIII/Analogizer)

Adapted to Analogizer by [@RndMnkIII](https://github.com/RndMnkIII) based on **agg23** NES for Analogue Pocket:
https://github.com/agg23/openfpga-NES
  
This Analogizer core uses a configuration file to select Analogizer adapter options, not based on the Pocket's menu system. It is necessary to run an external utility [Pupdate](https://github.com/mattpannella/pupdate) or [AnalogizerConfigurator](https://github.com/RndMnkIII/AnalogizerConfigurator)  to generate such a file. Once generated, you must copy the `analogizer.bin` file to the `/Assets/analogizer/common` folder on the Pocket SD card. If this folder does not exist, you must create it or if you have already extracted the Amiga core distribution file it will be created. Check the refered utility for the relevant options for the Analogizer adapter: SNAC controller, SNAC controller assigments (how to map physical SNAC game controllers to the Pocket openFPGA framework PAD format), Video output and Blank the Pocket Screen (On/Off).

This utility allows you to do a few things beyond the usual SNAC controller type and assignment, or video output type and blank of the Pocket screen.

The core can output RGBS, RGsB, YPbPr, Y/C and SVGA scandoubler (50% scanlines) video signals.
| Video output | Status | SOG Switch(Only R2,R3 Analogizer) |
| :----------- | :----: | :-------------------------------: |     
| RGBS         |  ✅    |     Off                           |
| RGsB         |  ✅    |     On                            |
| YPbPr        |  ✅🔹  |     On                            |
| Y/C NTSC     |  ✅    |     Off                           |
| Y/C PAL      |  ✅    |     Off                           |
| Scandoubler  |  ✅    |     Off                           |

🔹 Tested with Sony PVM-9044D

| :SNAC game controller:  | Analogizer A/B config Switch | Status |
| :---------------------- | :--------------------------- | :----: |
| DB15                    | A                            |  ✅    |
| NES/Zapper              | A                            |  ✅    |
| SNES                    | A                            |  ✅    |
| PCENGINE                | A                            |  ✅    |
| PCE MULTITAP            | A                            |  ✅    |
| PSX DS/DS2 Digital DPAD | B                            |  ✅    |
| PSX DS/DS2 Analog  DPAD | B                            |  ✅    |

The Analogizer interface allow to mix game inputs from compatible SNAC gamepads supported by Analogizer (DB15 Neogeo, NES, SNES, PCEngine, PSX) with Analogue Pocket built-in controls or from Dock USB or wireless supported controllers (Analogue support).

All Analogizer adapter versions (v1, v2 and v3) has a side slide switch labeled as 'A B' that must be configured based on the used SNAC game controller.
For example for use it with PSX Dual Shock or Dual Shock 2 native gamepad you must position the switch lever on the B side position. For the remaining
game controllers you must switch the lever on the A side position. 
Be careful when handling this switch. Use something with a thin, flat tip such as a precision screwdriver with a 2.0mm flat blade for example. Place the tip on the switch lever and press gently until it slides into the desired position:

```
     ---
   B|O  |A  A/B switch on position B
     ---   
     ---
   B|  O|A  A/B switch on position A
     ---
``` 

* **Analogizer** is responsible for generating the correct encoded Y/C signals from RGB and outputs to R,G pins of VGA port. Also redirects the CSync to VGA HSync pin.
The required external Y/C adapter that connects to VGA port is responsible for output Svideo o composite video signal using his internal electronics. Oficially
only the Mike Simone Y/C adapters (active) designs will be supported by Analogizer and will be the ones to use.
However, depending on the type of screen you have, passive Y/C adapters could work with different degrees of success.

Support native PCEngine/TurboGrafx-16 2btn, 6 btn gamepads and 5 player multitap using SNAC adapter
and PC Engine cable harness (specific for Analogizer). Many thanks to [Mike Simone](https://github.com/MikeS11/MiSTerFPGA_YC_Encoder) for his great Y/C Encoder project.

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

### Save States/Sleep + Wake and Saves

Are not supported with Analogizer version of NES core because the Pocket FPGA size don't allow to use Analogizer features and saves at the same time.

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

Core supports virtual lightguns by enabling the `Use Zapper > Emulated Zapper (Stick)` setting. The crosshair can be controlled with the D-Pad or left joystick, using the A button to fire. D-Pad aim sensitivity can be adjusted with the "D-Pad Aim Speed" setting. In addition, the Analogizer core version supports directly connecting the Zapper gun using a SNAC NES adapter  by enabling the `Use Zapper > SNAC Zapper` setting

**NOTE:** Joystick support for aiming only appears to work when a controller is paired over Bluetooth and not connected to the Analogue Dock directly by USB.
