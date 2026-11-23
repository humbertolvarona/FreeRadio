# FreeRadio: Native macOS Global Internet Radio Stream Tuner, Live Broadcast Recorder, Multi-Server Directory Explorer, and Personal Favorites Manager

**FreeRadio** (`FreeRadio.app`) is a native macOS desktop application built in **Swift 5.9+**, **SwiftUI**, **AppKit**, and **AVFoundation** that lets you discover, search, refresh, stream, record, and organize **40,000+ free internet radio stations broadcasting live from every country around the world**.

---

## Key Features

### 1. Global Live Radio Directory (40,000+ Free Stations)
- **Distributed Server Mirror Discovery & Failover**: Automatically queries `all.api.radio-browser.info` to discover active community Radio Browser API mirrors (`de1`, `fi1`, `nl1`, `at1`, `fr1`, etc.) and fails over seamlessly if a mirror goes offline.
- **Curated Discovery Views**:
  - **Top Voted**: Community-ranked global stations.
  - **Trending Now**: Most actively clicked live streams over the last 24 hours.
  - **Newly Added**: Recently registered or updated radio broadcasts.
  - **By Country**: Browse stations across 200+ countries with flag emojis and station counts.
  - **By Genre / Tag**: Explore thousands of musical and talk tags (`#jazz`, `#rock`, `#classical`, `#news`, `#ambient`, `#synthwave`, `#80s`, etc.).
  - **By Language**: Filter broadcasts by primary spoken language.

### 2. Live Station Search & Directory Updating (`Search & Update`)
- **Quick Search & Update Bar**: Type any station name, callsign, network, or genre in the top toolbar and click **Search & Update** (or press `Return`) to query the live global directory and update the station list immediately.
- **Advanced Multi-Filter Directory Search (`Directory Search`)**:
  - Filter simultaneously by **Station Name**, **Genre/Tag**, **Country**, **Language**, **Audio Codec** (`MP3`, `AAC`, `AAC+`, `OGG`, `FLAC`), and **Minimum Bitrate** (`64+`, `128+`, `192+`, `256+`, `320+ kbps`).
  - Sort results by **Most Votes**, **Most Popular**, **Trending**, **Highest Bitrate**, **Name (A-Z)**, or **Random**.
  - Toggle **HTTPS Only** and **Hide Broken** streams, and click **Update Stations Now** or **Refresh** (`⌘R`) anytime.
- **Instant In-View Filter (`Filter view...`)**: Narrow down the currently displayed list in real time as you type.

### 3. Favorites & Custom Stream Library
- **One-Click Favorites (`Favorites`)**: Click the heart icon (`♥`) on any station row, in the bottom Now Playing dock, via the right-click context menu, or press `⌘D` to add or remove favorites.
- **M3U & JSON Import / Export**:
  - Export your Favorites as a standard **M3U Playlist (`.m3u`)** compatible with VLC, IINA, or Apple Music.
  - Export and import your Favorites as a **JSON Backup (`.json`)**.
- **Custom Streams (`Custom Streams`)**: Add your own direct `MP3`, `AAC`, `OGG`, `FLAC`, or `HLS (.m3u8)` stream URLs (`⌘N`) with custom artwork, tags, codec, and bitrate metadata.

### 4. Native Audio Engine, Recorder, Visualizer & macOS Integration
- **ICY & HLS Live Track Metadata**: Automatically decodes live stream timed metadata to display the current song title or program name, with a one-click button to copy the track title to the clipboard.
- **Live Stream Recorder (`REC`)**: Record any active live broadcast directly to `~/Music/FreeRadio Recordings` with automatic timestamped naming, and play, reveal in Finder, or delete clips from the **Saved Recordings** tab.
- **Sleep Timer (`Timer`)**: Schedule automatic playback shutdown after **15, 30, 45, 60, or 90 minutes** with a live countdown badge.
- **Menu Bar Mini-Player (`MenuBarExtra`)**: Persistent radio icon in the macOS system status bar with Now Playing info, transport controls, **Surprise Me** button, and instant switching among your top Favorites—even when the main window is closed.
- **macOS Media Keys & Now Playing Center**: Integrates with `MPRemoteCommandCenter` and `MPNowPlayingInfoCenter` so hardware Play/Pause keys and Control Center widgets work out of the box.
- **Surprise Me (`🎲`)**: Tune in to a random station from your current view with one click or `⇧⌘R`.

---

## Project Architecture & Repository Layout

```text
freeRadio/
├── Package.swift                        # Swift Package Manager manifest (macOS 13.0+)
├── README.md                            # Comprehensive documentation & build guide
├── Sources/
│   └── FreeRadio/
│       ├── FreeRadioApp.swift           # @main App entry point, WindowGroup, MenuBarExtra & keyboard shortcuts
│       ├── MainWindowView.swift         # NavigationSplitView sidebar, top search/update toolbar & advanced filter bar
│       ├── Views_Components.swift       # StationRowView, context menus, animated spectrum visualizer & NowPlayingDockView
│       ├── Views_Modals.swift           # StationDetailSheet, AddCustomStationSheet & RecordingsListView
│       ├── RadioStore.swift             # Central state store, directory queries, Favorites, History & M3U/JSON I/O
│       ├── AudioPlayerManager.swift     # AVPlayer audio engine, ICY metadata decoder, Stream Recorder & Sleep Timer
│       ├── RadioBrowserAPI.swift        # Async/await Radio Browser API client with multi-mirror failover
│       └── Models.swift                 # RadioStation, CountryInfo, TagInfo, LanguageInfo, SearchFilters & RecordedClip
└── scripts/
    ├── build_app.sh                     # Automated script that generates AppIcon.icns, compiles release binary & signs FreeRadio.app
    └── generate_icon.swift              # CoreGraphics / AppKit script that renders the multi-resolution macOS AppIcon.iconset
```

---

## System Requirements

- **Operating System**: macOS 13.0 (Ventura) or newer (Apple Silicon `arm64` or Intel `x86_64`).
- **Build Toolchain**: Xcode 15+ or Xcode Command Line Tools (`swift --version` 5.9+, `iconutil`, `codesign`).

---

## How to Compile & Package `FreeRadio.app`

### Option A: Automated One-Command `.app` Bundle Build (Recommended)

Run the included build script from the project root:

```zsh
chmod +x scripts/build_app.sh
./scripts/build_app.sh
```

What `scripts/build_app.sh` does automatically:
1. Executes `scripts/generate_icon.swift` and `iconutil` to create the high-resolution macOS icon (`AppIcon.icns`).
2. Compiles the optimized production binary via `swift build -c release`.
3. Assembles the standard macOS application bundle structure (`FreeRadio.app/Contents/MacOS`, `Contents/Resources`, and `Contents/Info.plist`).
4. Applies an ad-hoc code signature (`codesign --force --deep --sign - FreeRadio.app`).

To launch the compiled application:

```zsh
open FreeRadio.app
```

Or install it into your macOS Applications folder:

```zsh
cp -R FreeRadio.app /Applications/
```

### Option B: Direct Swift Package Manager Build & Run

If you want to compile or run the executable directly via SwiftPM during development:

```zsh
# Debug build
swift build

# Release build
swift build -c release

# Run executable directly
.build/release/FreeRadio
```

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Space` | Play / Pause current radio stream |
| `⌘ →` | Next station in current list |
| `⌘ ←` | Previous station in current list |
| `⇧ ⌘ R` | **Surprise Me** (Play a random station) |
| `⌘ D` | Toggle **Favorite** on current station |
| `⇧ ⌘ E` | Start / Stop live stream **Recording** |
| `⌘ F` | Open **Directory Search & Update** view |
| `⌘ R` | **Refresh** current station list from online directory |
| `⇧ ⌘ M` | Switch to next **Global Directory Server Mirror** |
| `⌘ N` | Add a **Custom Radio Stream URL** |
| `⌘ 1` | Jump to **Favorites** |
| `⌘ 2` | Jump to **Top Voted** |

---

## License & Data Attribution

- Community station directory powered by the open [Radio Browser API](https://www.radio-browser.info/).
- Built natively for macOS with SwiftUI and AVFoundation.
