# Gear Audit Updater (Windows, personal use)

A small standalone Windows app that keeps Gear Audit up to date
without you having to download and copy files by hand.

No Python, no admin install, nothing to set up: Windows already
has everything it needs (PowerShell + Windows Forms).

## How to use it

1. Download or copy this whole `updater` folder anywhere on your
   Windows PC (Desktop is fine).
2. Double-click **`GearAuditUpdater.bat`**.
3. The app opens and:
   - finds your WoW AddOns folder automatically
     (`…\World of Warcraft\_retail_\Interface\AddOns`) — if it
     picks the wrong one, hit **Browse...** and pick the right
     folder once; it remembers your choice;
   - shows your installed version and the latest version on
     GitHub;
   - if an update is available, press **Update / Install
     Gear Audit**.
4. That's it. Your old version is moved to a
   `GearAudit_backup_<date>_<time>` folder next to it, just in
   case, and the new version takes its place.
5. If WoW was already running, type `/reload` in game (or
   restart WoW) to load the new version.

## What it does, exactly

- Latest version check: reads
  `GearAudit/GearAudit.toc` from the `main` branch of
  https://github.com/tyler3497/wow-gear-audit
- Update: downloads the `main` branch zip from GitHub, extracts
  it, and copies the `GearAudit` folder into your AddOns
  folder, replacing the old one (after backing it up).
- It never touches any other addon, and it never sends anything
  anywhere — it only downloads from that one GitHub repo.

## If it can't find your AddOns folder

Hit **Browse...** and navigate to it. The usual locations are:

- `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns`
- `C:\Program Files\World of Warcraft\_retail_\Interface\AddOns`

If WoW is on another drive, browse to that drive's equivalent
path. Your choice is saved in
`%APPDATA%\GearAuditUpdater\settings.json`.

## Files

- `GearAuditUpdater.bat` — double-click this to run the app.
- `GearAuditUpdater.ps1` — the app itself (PowerShell + Windows
  Forms). You can read it: it's plain text, no compiled code.
- `README.md` — this file.

## Troubleshooting

- **"Could not reach GitHub"** — check your internet connection
  and try Check for Update again.
- **"Folder not found"** — use Browse... to pick the real
  AddOns folder (it must end in `Interface\AddOns`).
- **Windows SmartScreen / execution policy warning** — the .bat
  runs PowerShell with `-ExecutionPolicy Bypass` for this script
  only. If Windows still blocks it, right-click the .bat,
  Properties, and tick Unblock if present, then run it again.
- **Addon not showing the new version in game** — `/reload` or
  restart WoW; files on disk don't reload a running client
  by themselves.
