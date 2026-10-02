# Sanctuary — Church Sound-Booth Dashboard (Phase 1)

A Swift/SwiftUI dashboard for running a church sound booth from the Apple
ecosystem: a **macOS app** in the booth as the hub, an **iPadOS app** as the
remote dashboard, synced over the local network. Apple frameworks only —
no third-party dependencies.

Phase 1 covers: dashboard shell, setup/teardown **checklists**, a **run of
show** with cue timers, and a **software audio playback engine** (play backing
tracks, bumpers, preshow loops with faders, mutes, and fade-outs).

## Architecture

```
┌──────────────────┐   MultipeerConnectivity    ┌──────────────────┐
│   iPad Remote    │ ◄── service "sanctuary-av" ──► │     Mac Hub      │
│  (SanctuaryUI)   │      Wi-Fi / Bluetooth       │  (SanctuaryUI)   │
│                  │                              │                  │
│ - checklists     │   SyncMessage (JSON)         │ - checklists     │
│ - run of show    │   checklist toggles          │ - run of show    │
│ - faders/mutes   │   cue advance                │ - AVAudioEngine  │
│ - transport      │   fader/mute/volume          │   playback       │
└──────────────────┘   full-state snapshot       └────────┬─────────┘
                                                         │ AVAudioEngine
                                                         │ (per-track nodes,
                                                         │  master mixer)
                                                         ▼
                                                   USB audio ──► Yorkville VGM14
                                                                 (ANALOG — see below)
```

- **SanctuaryCore** (Swift package): models, `PlaybackEngine`
  (AVAudioEngine), `BoothSyncService` (MultipeerConnectivity), `BoothStore`
  (central `ObservableObject` state + sync wiring), `DeviceControl` protocol +
  Phase 2/3 driver stubs.
- **SanctuaryUI** (Swift package): all SwiftUI views + the `@main`
  `SanctuaryApp`. Sidebar on macOS, tabs on iPad.
- The Mac is the **source of truth**. The iPad requests a full-state snapshot
  when it connects; afterwards both sides broadcast `SyncMessage`s for every
  local change. Incoming messages never re-broadcast (no echo loops).

## Honest limitations (read first)

1. **The Yorkville VGM14 is fully analog.** No MIDI, no OSC, no network
   control, no motorized faders. No software can move its faders or recall
   scenes on it — that is a hardware fact, not a software gap. Phase 1
   faders/mutes control **software playback tracks on the Mac only** (backing
   audio routed into the mixer over USB). True remote fader control needs a
   digital mixer; that's the documented Phase 3 upgrade path.
2. **No audio files are bundled.** The three seeded tracks (`Preshow Loop`,
   `Worship Pad`, `Sermon Bumper`) have no files until you drop them into
   `Sources/SanctuaryCore/Media/` and set `fileName` in the seed data. Until
   then their play buttons stay disabled and the engine logs a hint.
3. **MultipeerConnectivity range** is one room / one LAN segment (Wi-Fi or
   Bluetooth). Both devices must be on the same booth network. Volume-slider
   drags broadcast every tick — fine for a LAN, worth throttling later.
4. **Not yet implemented (by design):** OBS streaming/video switching,
   VideoPsalms lyrics control, DMX lighting. The Devices tab shows these as
   "Not connected — Phase 2/3" placeholders; drivers plug into the
   `DeviceControl` protocol.

## Xcode setup

1. **Create the app target:** File → New → Project → App. Name it
   `Sanctuary`, interface **SwiftUI**, language **Swift**. (One multiplatform
   target is fine, or separate macOS + iOS targets.)
2. **Delete** the template's `SanctuaryApp.swift` / `ContentView.swift` — the
   `@main` entry point lives in the `SanctuaryUI` package
   (`Sources/SanctuaryUI/SanctuaryApp.swift`). An app target with no `@main`
   of its own uses the one from the linked package.
3. **Add the local package:** File → Add Package Dependencies… → Add Local…
   → select this `sanctuary/` folder. Add both `SanctuaryUI` (and transitively
   `SanctuaryCore`) to the app target's Frameworks.
4. **Info.plist** — local networking requires:
   - `NSLocalNetworkUsageDescription` — e.g. *"Sanctuary syncs the booth dashboard between Mac and iPad over the local network."*
   - `NSBonjourServices` — array containing `_sanctuary-av._tcp`
5. **Signing:** set your Team; Multipeer + audio need no special entitlements.
6. Build & run on the Mac, then on the iPad (same Wi-Fi). The Overview tab's
   Sync card shows the connection; the iPad pulls full state on connect.

Run the package tests any time with `swift test` from this folder
(models + sync-protocol round-trips; Apple-framework code paths need Xcode).

## Project layout

```
sanctuary/
├── Package.swift
├── README.md
├── Sources/
│   ├── SanctuaryCore/
│   │   ├── Models/
│   │   │   ├── Checklist.swift      # Checklist / ChecklistItem + progress
│   │   │   ├── RunOfShow.swift      # Cue / CueKind / RunOfShow + helpers
│   │   │   ├── AudioTrack.swift     # software playback track
│   │   │   └── SyncMessage.swift    # Codable wire protocol + BoothSnapshot
│   │   ├── Sync/
│   │   │   └── BoothSyncService.swift  # MultipeerConnectivity wrapper
│   │   ├── Audio/
│   │   │   └── PlaybackEngine.swift    # AVAudioEngine, per-track nodes, meters
│   │   ├── Store/
│   │   │   └── BoothStore.swift        # central state + seed data + sync apply
│   │   ├── Devices/
│   │   │   ├── DeviceControl.swift     # driver protocol
│   │   │   └── FutureDrivers.swift     # Phase 2/3 stubs + catalogue
│   │   └── Media/                   # drop audio files here (see README.txt)
│   └── SanctuaryUI/
│       ├── SanctuaryApp.swift       # @main App (hosted by the Xcode target)
│       ├── Views/
│       │   ├── DashboardView.swift  # sidebar (macOS) / tabs (iPad)
│       │   ├── OverviewView.swift   # status cards + quick actions
│       │   ├── ChecklistView.swift
│       │   ├── RunOfShowView.swift  # cue list + live timers
│       │   ├── AudioMixerView.swift # channel strips + master
│       │   └── DevicePlaceholderView.swift
│       └── Components/
│           ├── LevelMeter.swift
│           └── TimeFormatting.swift
└── Tests/
    └── SanctuaryCoreTests/
        └── ModelTests.swift
```

## Roadmap

- **Phase 1 (this):** dashboard shell, checklists, run of show, software
  audio playback, iPad remote sync, `DeviceControl` protocol + stubs.
- **Phase 2:** OBS Studio driver (obs-websocket: stream start/stop,
  recording, software video switching) and VideoPsalms lyrics remote.
- **Phase 3:** DMX lighting driver (USB-DMX interface) and the digital-mixer
  upgrade path for true remote faders.

## Implementation notes / deviations from the brief

- `SyncMessage` gained two cases beyond the brief: `trackTransport` (per-track
  play/pause/stop — the brief's `transport` is master-only: all tracks +
  cue nav) and `masterVolumeChanged`. Both are encoded/decoded and tested.
- The brief's `TransportCommand` semantics: `play` resumes all paused tracks,
  `pause` pauses all playing tracks, `stop` stops everything, `nextCue` /
  `prevCue` navigate cues.
- `Components/TimeFormatting.swift` is an extra small helper (cue timers).
- `PlaybackEngine.isLoaded(trackID:)` was added so the UI can disable play on
  tracks with no audio file.
- Both devices advertise + browse simultaneously (zero-config); the iPad
  auto-requests full state on connect, the Mac only answers.
- Fade-outs are Timer-driven on the main thread; remote peers get a plain
  stop for fades (documented in `BoothStore.fadeOutTrack`).
- Loop re-scheduling uses a per-track generation counter so a stale
  completion callback can't resurrect a stopped track.

## Needs real hardware to verify

- Multipeer discovery + sync between an actual Mac and iPad on the booth LAN.
- Audio playback latency/levels through the VGM14's USB input; meter scaling.
- `Bundle.module` resource lookup for `Media/` files once added in Xcode.
- iOS audio-session behavior (`.playback` category) with the iPad as a
  pure remote (no audio needed there, but the session code is shared).
