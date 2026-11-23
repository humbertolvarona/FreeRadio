import SwiftUI
import AppKit

struct MenuBarPlayerView: View {
    @ObservedObject var store: RadioStore
    @ObservedObject var player: AudioPlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "radio.fill")
                    .foregroundColor(.accentColor)
                Text("FreeRadio World Tuner")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if player.isPlaying {
                    Text("ON AIR")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }

            Divider()

            if let st = player.currentStation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(st.flagEmoji) \(st.displayName)")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if !player.liveMetadataTitle.isEmpty {
                        Text("♪ \(player.liveMetadataTitle)")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    } else {
                        Text("\(st.displayCountry) • \(st.displayCodec) • \(st.displayBitrate)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No station currently playing")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    store.playPreviousStation()
                } label: {
                    Image(systemName: "backward.end.fill")
                }

                Button {
                    if player.currentStation != nil {
                        player.togglePlayPause()
                    } else {
                        store.playRandomStation()
                    }
                } label: {
                    Label(
                        player.isPlaying ? "Pause" : "Play",
                        systemImage: player.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.playNextStation()
                } label: {
                    Image(systemName: "forward.end.fill")
                }

                Button {
                    store.playRandomStation()
                } label: {
                    Image(systemName: "dice.fill")
                }
                .help("Surprise Me")
            }

            if !store.favorites.isEmpty {
                Divider()
                Text("Quick Favorites")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                ForEach(store.favorites.prefix(6)) { fav in
                    Button {
                        store.playStation(fav)
                    } label: {
                        HStack {
                            Text("\(fav.flagEmoji) \(fav.displayName)")
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            if player.currentStation?.stationuuid == fav.stationuuid && player.isPlaying {
                                Image(systemName: "waveform")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Button("Show Main Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                Spacer()
                Button("Quit FreeRadio") {
                    NSApp.terminate(nil)
                }
            }
            .font(.system(size: 11))
        }
        .padding(14)
        .frame(width: 290)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            for window in NSApp.windows where window.title.contains("FreeRadio") || window.contentView != nil {
                if window.frame.width < 1260 {
                    var frame = window.frame
                    let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
                    let targetWidth = min(1320, screenFrame.width - 40)
                    let targetHeight = min(max(frame.height, 780), screenFrame.height - 40)
                    frame.size = CGSize(width: targetWidth, height: targetHeight)
                    frame.origin.x = screenFrame.origin.x + (screenFrame.width - targetWidth) / 2
                    frame.origin.y = screenFrame.origin.y + (screenFrame.height - targetHeight) / 2
                    window.setFrame(frame, display: true, animate: true)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct FreeRadioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = RadioStore()
    @StateObject private var player = AudioPlayerManager.shared

    var body: some Scene {
        WindowGroup("FreeRadio — Global Internet Radio Tuner") {
            MainWindowView(store: store, player: player)
                .frame(minWidth: 1220, idealWidth: 1320, minHeight: 740, idealHeight: 820)
        }
        .defaultSize(width: 1320, height: 820)
        .commands {
            CommandMenu("Controls") {
                Button(player.isPlaying ? "Pause Stream" : "Play Stream") {
                    if player.currentStation != nil {
                        player.togglePlayPause()
                    } else {
                        store.playRandomStation()
                    }
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Next Station") {
                    store.playNextStation()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Previous Station") {
                    store.playPreviousStation()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Button("Surprise Me (Random Station)") {
                    store.playRandomStation()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Toggle Favorite on Current Station") {
                    if let current = player.currentStation {
                        store.toggleFavorite(current)
                    }
                }
                .keyboardShortcut("d", modifiers: [.command])
                .disabled(player.currentStation == nil)

                Button(player.isRecording ? "Stop Stream Recording" : "Start Stream Recording") {
                    player.toggleRecording()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(player.currentStation == nil)
            }

            CommandMenu("Directory") {
                Button("Search & Update Stations...") {
                    store.selectedSection = .search
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Refresh Current Station List") {
                    Task {
                        await store.loadCurrentSection(forceRefresh: true)
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Switch Global Directory Server Mirror") {
                    Task {
                        await store.switchMirrorAndReload()
                    }
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Divider()

                Button("Add Custom Stream URL...") {
                    store.showAddCustomStationSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Go to Favorites") {
                    store.selectedSection = .favorites
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Go to Top Voted") {
                    store.selectedSection = .discover
                }
                .keyboardShortcut("2", modifiers: [.command])

                Divider()

                Button("Export Favorites as M3U Playlist...") {
                    store.exportFavoritesAsM3U()
                }
                Button("Export Favorites as JSON Backup...") {
                    store.exportFavoritesAsJSON()
                }
                Button("Import Favorites from JSON...") {
                    store.importFavoritesFromJSON()
                }
            }
        }

        MenuBarExtra(
            "FreeRadio",
            systemImage: player.isPlaying ? "dot.radiowaves.left.and.right" : "radio"
        ) {
            MenuBarPlayerView(store: store, player: player)
        }
        .menuBarExtraStyle(.window)
    }
}
