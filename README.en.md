# FMLAB Cleaner 🧹📱

[🇮🇹 Italiano](README.md) · 🇬🇧 English

<p align="center"><img src="Risorse/logo-256.png" width="140" alt="FMLAB logo"></p>

**FMLAB Cleaner** is an iPhone app that frees up space safely and shows the phone's real status.
Everything stays on the phone: no internet (except the update check), no subscriptions, no ads.
The app follows the iPhone language (Italian or English).

<p align="center">
  <img src="screenshots/pulizia.png" width="24%" alt="Clean">
  <img src="screenshots/file.png" width="24%" alt="Files">
  <img src="screenshots/app.png" width="24%" alt="App">
  <img src="screenshots/telefono.png" width="24%" alt="Phone">
</p>

<sub>Screenshots of 1.9.0. Older versions are in [`screenshots/`](screenshots/), one folder per version.</sub>

## Install

1. Open **LiveContainer** → **+** → **Install from URL** and paste:
   `https://github.com/cipherdesk007-max/FMLAB-cleaner/releases/download/ultima/FMLAB-Cleaner.ipa`
2. On first launch allow **Full Access** to Photos (the prompt shows LiveContainer's name).

Updates are announced inside the app: **Copy install link**, then in LiveContainer + → Install from URL → Paste.
It installs over the old version and keeps your data. Works with SideStore/AltStore as a normal app too.

## What it does

| Tab | What it does |
|---|---|
| **Clean** | **Similar photos** (keeps the sharpest), **blurry** and **dark** photos with the deep analysis; large videos (largest first; remove or **compress** to about half), **Live Photo → photo** (drops the 3-second video), identical duplicates (the original stays), screen recordings, screenshots, unpicked burst shots. **Empty "Recently Deleted"** in one go |
| **Files** | Files-app folders you pick (Downloads, On My iPhone, iCloud Drive): large files, verified duplicates, archives and installers, old files; tap a folder to **explore** what's inside, largest first. Recommended: add **On My iPhone**, which contains everything. Everything goes to the Files trash (30 days). Inside LiveContainer the "On My iPhone → LiveContainer" folder is cleaned automatically and the folder picker works with no settings to change |
| **Apps** | Only inside LiveContainer: space used by each hosted app, clear caches and temp files, remove leftover .ipa files and data of uninstalled apps |
| **Phone** | Battery, Low Power Mode, thermal state as reported by iOS, storage, memory, uptime, tips ordered by impact |

**Safety**: nothing is deleted without your choice; iOS always asks to confirm and photos/videos go to
*Recently Deleted* (30 days). The Apps tab only removes caches, temp files, .ipa files and orphaned data, never
documents or data of installed apps.

**What no iPhone app can do** (apps that promise it do nothing real): free RAM, close other apps, "repair" the
battery, delete iOS files or files of apps outside LiveContainer.

## Made for LiveContainer

FMLAB Cleaner is built to run inside **[LiveContainer](https://github.com/LiveContainer/LiveContainer)**
(by [khanhduytran0](https://github.com/khanhduytran0) and contributors), installed with
**[SideStore](https://github.com/SideStore/SideStore)**. It has features made for it: the **App** tab (space used by
hosted apps, caches, leftover .ipa files, leftover app data shown with the real app name), the automatic
*On My iPhone → LiveContainer* folder, and a **folder picker and file removal that work without changing
LiveContainer's settings** (the same fix as "Fix File Picker", applied by the app itself).
It also works as a normally installed app, without the App tab.

**Where it can help** (LiveContainer and SideStore communities):
- [r/sideloaded](https://www.reddit.com/r/sideloaded/) — SideStore + LiveContainer guides and help
- [r/EmulationOniOS](https://www.reddit.com/r/EmulationOniOS/) — people running emulators and games in LiveContainer
- [LiveContainer discussions on GitHub](https://github.com/LiveContainer/LiveContainer/discussions)
- the SideStore Discord server (link on [sidestore.io](https://sidestore.io))

Thanks to LiveContainer and SideStore: without them this app would have nowhere to run.

## Reports

Problems, ideas and requests: [open an issue here](https://github.com/cipherdesk007-max/FMLAB-cleaner/issues/new).
The app has the button too, at the bottom of the Clean tab (**Source and reports**).

## Privacy

Photos never leave the phone: scanning, compression and conversion all run on the iPhone. The only network
request is the update check, which reads a version number from GitHub. No ads, no analytics, no accounts.

## How it's built

- SwiftUI + PhotoKit, iOS 15+, Italian and English. Sources in [`Sorgenti/`](Sorgenti/).
- FMLAB colors: red `#BF6D6F` (from the logo) on black.
- Built by GitHub Actions on Linux with [Theos](https://github.com/theos/theos) (no Mac needed): every change on
  `main` publishes a numbered release and the **ultima** (latest) release the app updates from.
- History: [CHANGELOG.md](CHANGELOG.md). License: [MIT](LICENSE).

Part of the FMLAB family with [FMlab - RunnerKit](https://github.com/cipherdesk007-max/FMlab---RunnerKit)
(Linux on iPhone with LinuxRunner).
