# Gaar.Deepward — client addons

Client addons for the **Deepward** WoW 3.3.5a (WotLK) realm. Two addons:

- **DeepwardUI** — quality-of-life UI: custom spell book + native-spellbook markers, cross-faction
  invite, sell-junk / sell-bags, quest guard, auto-bind confirms, and a **mount-anywhere** helper
  (`/dwmount`, `/dwm`, or the "Mount (anywhere)" keybinding — mounts you indoors, where the client
  greys the normal mount button).
- **DeepwardTiers** — the tiered-progression panel (your current tier, dungeon clears, Advance).

## Install

**Option A — zip (easiest):**
1. Download **`Deepward_Addons.zip`** (both addons) from this repo.
2. Extract it into `World of Warcraft/Interface/AddOns/` so you get
   `Interface/AddOns/DeepwardUI/` and `Interface/AddOns/DeepwardTiers/`.
3. Restart the client (or `/reload`), and make sure both are ticked in the AddOns list at the
   character-select screen.

**Option B — git:**
```
git clone https://github.com/Tgaarden/Gaar.Deepward.git
```
Copy the `DeepwardUI/` and `DeepwardTiers/` folders into `World of Warcraft/Interface/AddOns/`.

## Keybindings
Key Bindings → **Deepward**: "Mount (anywhere)" and "Toggle Spell Book".

## Updating
Re-download the zip (or `git pull`) and replace the folders. The addons target interface **30300**
(WotLK 3.3.5a).
