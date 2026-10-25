# Gear Audit — a retail World of Warcraft addon

Quickly view the equipped gear of everyone in your party or raid, with
an overall item-level view, a click-through detail view per player, and
an audit for missing enchants and gems.

Built for retail **Midnight 12.1.5 (Interface 120105)**. It uses the
modern `C_Item` / `C_ClassColor` / `C_TooltipInfo` APIs — the old
globals `GetItemInfo` and `GetItemQualityColor` were removed in
Midnight and are never called unguarded. The UI is a modern dark
theme: flat panels, thin borders, an accent bar, item icons bordered
in quality colour, and mouse-wheel scrolling.

## Install

1. Copy the `GearAudit` folder into your WoW addons folder:
   - Windows: `World of Warcraft\_retail_\Interface\AddOns\GearAudit`
   - Mac: `World of Warcraft/_retail_/Interface/AddOns/GearAudit`
2. Restart WoW (or `/reload` if the game is already running).
3. At the character select screen, make sure **Gear Audit** is ticked
   in AddOns. If the TOC version is behind your client, tick
   **Load out of date AddOns** or bump the `## Interface` line in
   `GearAudit.toc` to your client's interface version.

## Use

- Type `/ga`, `/gear`, or `/gearaudit` to open the window.
- Press **Refresh All** to inspect your party or raid. Players are
  inspected one at a time (the game throttles inspects), so a full
  raid takes a few seconds. Your own gear needs no inspect.
- The overview is sorted by average item level, highest first, and
  shows per player:
  - **Player** — name, coloured by class
  - **Class / Spec** — the spec icon (hover it for the written
    "Class • Spec • Role"; the written name is used if no icon
    is available)
  - **Role** — Tank, Healer, or DPS (from the player's spec)
  - **iLvl** — average equipped item level
  - **Enchants** — `OK`, or how many enchants are missing
  - **Gems** — `OK`, or how many gems are missing
- **Click a player** to open the detail panel: the player's class,
  spec, and role, a large average item level at the top, and every
  slot with its item level, its upgrade track (e.g. Champion 4/6,
  Hero 5/6, Myth 6/6 — `—` for non-upgradeable gear), and its
  enchant/gem status. Hover an item for its tooltip.
  Shift-click an item to drop its link into chat.
- **Re-inspect Player** re-checks just the selected player.

## What the audit flags (and what it does not)

- **Missing enchants:** only slots that can take an enchant in retail
  are flagged — Back, Chest, Wrist, Legs, Feet, Rings, and weapons.
  Head, Neck, Shoulder, Hands, Waist, and Trinkets are never flagged,
  because they take no enchant in retail. Off-hand is only flagged
  for weapons and shields.
- **Missing gems:** a gem is only flagged when the game's tooltip
  data proves a socket exists and is empty. If socket data is
  unavailable for an item, that item is not flagged, rather than
  risking a false positive.
- **Out of range / timed out:** a player who cannot be inspected
  (out of range, left the group, or the server did not answer within
  5 seconds) shows `—` in the overview instead of a guessed number.

## Files

- `GearAudit/GearAudit.toc` — addon manifest
- `GearAudit/Audit.lua` — item-link parsing, enchant/gem audit rules
- `GearAudit/Core.lua` — group roster, inspect queue, slash commands
- `GearAudit/UI.lua` — overview list and detail panel

## Limitations

- Inspecting requires players to be in range and inspectable, the
  same as the default inspect UI. This addon does not bypass that.
- Average item level is the mean of equipped items found. An empty
  slot (for example, no off-hand on a two-handed weapon user)
  is excluded rather than counted as zero.
- Enchantable slots change between expansions. If Blizzard adds or
  removes one, update `GA.ENCHANTABLE_SLOTS` in `Audit.lua`.
