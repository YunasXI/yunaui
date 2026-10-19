# YunaUI

A complete, clean HUD for **CatsEyeXI** (Ashita v4 / VanaCore), made to look like one modern interface: thin glowing bars,
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

1. Download the latest release zip and unzip it into `Ashita\addons\` (so you have `Ashita\addons\yunaui\yunaui.lua`).
   On VanaCore use `VanaCore\addons\ashita\` instead.
2. In game: `/addon load yunaui`. Add that line to your startup script to load it every time.
3. The first time, a short guide shows what every piece does, then Edit Mode opens: place everything, then press **DONE**.

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
[YunaUI Icons](https://github.com/YunasXI/yunaui-icons): extract its zip into your `addons` folder.

## Credits

- Enmity values from LandSandBoat. Cooldown reading follows the Timers addon.
- Font: TeX Gyre Adventor (GUST Font License). Animated effects: FootageCrate.
- Job hats and buff icons redrawn for YunaUI.

## Licence

YunaUI is released under the GNU General Public License v3.0 (see `LICENSE`), because it includes GPL-3.0 code from XIUI.
