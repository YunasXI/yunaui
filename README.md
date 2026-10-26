# YunaUI

A complete, clean HUD for **CatsEyeXI** (VanaCore, the CatsEyeXI launcher's client), made to look like one modern interface: thin glowing bars,
the AvantGarde-style font everywhere, and every piece placed where you like.

## What's in it

- **Target bar**: a glowing white line in a magenta band, with the target's distance.
  Under it: what the monster is casting or readying, and its buffs / debuffs with their time left.
- **Skillchains**: when your party opens a chain, a fan shows your weapon skills that close it (best on top).
  When a skillchain lands, a **Magic Burst** card shows the chain, the elements to burst with and the time left.
- **Target of target** and an **enemy list** (click a monster to target it).
- **Party and alliances**: job tag in its role colour, name, HP, MP and TP. A member under 30% HP trembles and beats red.
  Members fade in when they join and slide away when they leave. Click a job tag to fold that member's buffs.
- **Your HP / MP / TP bars**, which can be anchored together, plus a **cast bar**, **EXP**, **gil** and **bag**.
- **Pet bar** with its HP / MP / TP, its ability timers and what it is fighting.
- **Timers** for your abilities and spells.
- **Gear strip**: your 16 equipped items in HD; it lights up when you swap gear.
- **Damage Meter** (formerly YunaDPS), with an enmity view.
- **Chat** with channel tabs, an optional combat log you can anchor beside it, timestamps and saved chat logs.
- **Edit Mode**: every piece on a grid; drag it and it snaps into line. Ready-made layouts, and five of your own with a name.
- Everything stays on screen at any resolution.

## Install

YunaUI is a **VanaCore** addon (VanaCore is the client the CatsEyeXI launcher starts). It does not run on plain Ashita.

1. Download the latest release zip and unzip it into `VanaCore\addons\vanacore\` (so you have
   `VanaCore\addons\vanacore\yunaui\yunaui.lua`).
2. In game: `/addon load yunaui vanacore`. Add that line to your startup script to load it every time.

**Updating from 1.0.24 or older?** Those went in `VanaCore\addons\ashita\yunaui`. Delete that folder (your settings
are kept), unzip the new one as above, and change `/addon load yunaui` in your startup script to
`/addon load yunaui vanacore`. The old `VanaCore\addons\vanacore\yunalink` helper isn't needed anymore: you can delete it too.
3. The first time, a short guide shows what every piece does, then Edit Mode opens: place everything, then press **DONE**.

**Changes to the game's interface** (through VanaCore, put back as soon as YunaUI is unloaded): while YunaUI's own
pieces are on, the game's chat log, party list, alliance lists and Target window are hidden (the chat line too, if
you choose), and the network window is hidden. Turn a YunaUI piece off and the game's own comes back.

## Commands

| Command | What it does |
| --- | --- |
| `/yui` | Open or close the settings |
| `/yui edit` | Edit Mode: move every piece |
| `/yui guide` | The first-time guide again |
| `/yui lock` / `/yui unlock` | Stop or allow dragging |
| `/yui reset` | Back to the default settings |
| `/dps` | The Damage Meter's own commands |

## HD icons (optional)

YunaUI uses the game's own item and buff icons. For sharper HD ones, install the separate pack
[YunaUI Icons](https://github.com/YunasXI/yunaui-icons): extract its zip into `VanaCore\addons\vanacore\` (the folder that holds `yunaui`).

## Credits

- Enmity values from LandSandBoat. Cooldown reading follows the Timers addon.
- Font: TeX Gyre Adventor (GUST Font License). Animated effects: FootageCrate.
- Job hats and buff icons redrawn for YunaUI.
- Minimap: 2D maps restyled from remapster HD maps (remapster.com, by spalose), the ffxi-maps 1024x1024 map pack, and
  Vana'diel Atlas / ffxi-atlas.com maps, used with permission; 3D zone shapes from LandSandBoat's xiNavmeshOBJs (GPL-3.0);
  map table and floor reading after boussole by loonsies. FINAL FANTASY XI map art (c) SQUARE ENIX.

## Using YunaUI in your own work

YunaUI is made by **Yunas**. You are welcome to build on it, as long as you credit it:

- **Using its code or files** (code, layouts, artwork, icons, in whole or in part): credit is **required**. Keep the
  `NOTICE` file and the credits in the files, and put this in your README:
  `Based on YunaUI by Yunas - https://github.com/YunasXI/yunaui`
- **Inspired by its look or ideas** (your own code): please credit it the same way.

## Licence

YunaUI is released under the GNU General Public License v3.0 (see `LICENSE`), because it includes GPL-3.0 code from XIUI,
with one additional term (GPL-3.0 section 7(b)) for the parts written by Yunas: the author credit must be kept (see `NOTICE`).

Copyright (C) 2026 Yunas.
