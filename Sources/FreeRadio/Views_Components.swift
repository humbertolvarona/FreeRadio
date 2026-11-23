import SwiftUI
import AppKit

struct StationRowView: View {
    let station: RadioStation
    @ObservedObject var store: RadioStore
    @ObservedObject var player: AudioPlayerManager

    var isCurrent: Bool {
        player.currentStation?.stationuuid == station.stationuuid
    }

    var isFav: Bool {
        store.isFavorite(station)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Artwork / Favicon + Play button overlay
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCurrent ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                    .frame(width: 48, height: 48)

                if let fav = station.favicon, let url = URL(string: fav), !fav.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        default:
                            Text(station.flagEmoji)
                                .font(.system(size: 22))
                        }
                    }
                } else {
                    Text(station.flagEmoji)
                        .font(.system(size: 22))
                }

                if isCurrent && player.isPlaying {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 48, height: 48)
                    Image(systemName: player.isBuffering ? "hourglass" : "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .onTapGesture {
                if isCurrent {
                    player.togglePlayPause()
                } else {
                    store.playStation(station)
                }
            }

            // Station Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(station.displayName)
                        .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                        .foregroundColor(isCurrent ? .accentColor : .primary)
                        .lineLimit(1)

                    if station.hls == 1 {
                        Text("HLS")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                    }

                    if station.isCustom == true {
                        Text("CUSTOM")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text("\(station.flagEmoji) \(station.displayCountry)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let lang = station.language, !lang.isEmpty {
                        Text("• \(lang.capitalized)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if !station.tagList.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(station.tagList.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .foregroundColor(.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Spacer()

            // Technical Badges
            HStack(spacing: 6) {
                Text(station.displayCodec)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.14))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                Text(station.displayBitrate)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.14))
                    .foregroundColor(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                if let votes = station.votes, votes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 9))
                        Text("\(votes)")
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                }
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    if isCurrent {
                        player.togglePlayPause()
                    } else {
                        store.playStation(station)
                    }
                } label: {
                    Image(systemName: (isCurrent && player.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(isCurrent && player.isPlaying ? "Pause Stream" : "Play Stream")

                Button {
                    store.toggleFavorite(station)
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isFav ? .pink : .secondary)
                }
                .buttonStyle(.plain)
                .help(isFav ? "Remove from Favorites" : "Add to Favorites")

                Button {
                    store.inspectedStation = station
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Station Details & Stream URL")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            store.playStation(station)
        }
        .contextMenu {
            Button {
                store.playStation(station)
            } label: {
                Label("Play Station", systemImage: "play.fill")
            }

            Button {
                store.toggleFavorite(station)
            } label: {
                Label(isFav ? "Remove from Favorites" : "Add to Favorites", systemImage: isFav ? "heart.slash" : "heart.fill")
            }

            Button {
                store.voteForStation(station)
            } label: {
                Label("Vote Up in Global Directory", systemImage: "hand.thumbsup")
            }

            Divider()

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(station.streamURLString, forType: .string)
                store.showBanner("Copied stream URL to clipboard.")
            } label: {
                Label("Copy Direct Stream URL", systemImage: "doc.on.doc")
            }

            if let homepage = station.homepage, let url = URL(string: homepage), !homepage.isEmpty {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open Station Website", systemImage: "safari")
                }
            }

            Button {
                store.inspectedStation = station
            } label: {
                Label("Inspect Station Metadata", systemImage: "info.circle")
            }

            if station.isCustom == true {
                Divider()
                Button(role: .destructive) {
                    store.deleteCustomStation(station)
                } label: {
                    Label("Delete Custom Stream", systemImage: "trash")
                }
            }
        }
    }
}

struct NowPlayingDockView: View {
    @ObservedObject var store: RadioStore
    @ObservedObject var player: AudioPlayerManager

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if let err = player.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(err)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button("Dismiss") {
                        player.errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.15))
            }

            HStack(spacing: 18) {
                // Current Station Info
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 52, height: 52)

                        if let st = player.currentStation,
                           let fav = st.favicon,
                           let url = URL(string: fav),
                           !fav.isEmpty {
                            AsyncImage(url: url) { phase in
                                if case .success(let image) = phase {
                                    image.resizable().scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    Text(st.flagEmoji).font(.system(size: 24))
                                }
                            }
                        } else {
                            Image(systemName: "radio.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        if let st = player.currentStation {
                            HStack(spacing: 6) {
                                Text(st.displayName)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(1)

                                if player.isBuffering {
                                    ProgressView()
                                        .controlSize(.small)
                                } else if player.isPlaying {
                                    Text("LIVE")
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                            }

                            if !player.liveMetadataTitle.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 10))
                                        .foregroundColor(.accentColor)
                                    Text(player.liveMetadataTitle)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(player.liveMetadataTitle, forType: .string)
                                        store.showBanner("Copied track title: \(player.liveMetadataTitle)")
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy Track Title")
                                }
                            } else {
                                Text("\(st.flagEmoji) \(st.displayCountry) • \(st.displayCodec) • \(st.displayBitrate)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("No Station Selected")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Choose any station from the directory or click 'Surprise Me'")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(minWidth: 270, maxWidth: 360, alignment: .leading)

                // Live Audio Spectrum Visualizer
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<player.visualizerLevels.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.accentColor, .cyan],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 4, height: max(4, 32 * player.visualizerLevels[i]))
                            .animation(.easeInOut(duration: 0.14), value: player.visualizerLevels[i])
                    }
                }
                .frame(height: 34)
                .padding(.horizontal, 6)

                Spacer()

                // Transport Controls
                HStack(spacing: 14) {
                    Button {
                        store.playPreviousStation()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .help("Previous Station")

                    Button {
                        if player.currentStation != nil {
                            player.togglePlayPause()
                        } else {
                            store.playRandomStation()
                        }
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help(player.isPlaying ? "Pause" : "Play")

                    Button {
                        player.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .disabled(!player.isPlaying && !player.isBuffering)
                    .help("Stop Stream")

                    Button {
                        store.playNextStation()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .help("Next Station")

                    Button {
                        store.playRandomStation()
                    } label: {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("Surprise Me (Tune in to a Random Station)")
                }

                Spacer()

                // Extra Controls: Favorite, Record, Sleep Timer, Volume
                HStack(spacing: 14) {
                    if let current = player.currentStation {
                        Button {
                            store.toggleFavorite(current)
                        } label: {
                            Image(systemName: store.isFavorite(current) ? "heart.fill" : "heart")
                                .font(.system(size: 17))
                                .foregroundColor(store.isFavorite(current) ? .pink : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(store.isFavorite(current) ? "Remove from Favorites" : "Add to Favorites")
                    }

                    // Stream Recorder Button
                    Button {
                        player.toggleRecording()
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(player.isRecording ? Color.red : Color.secondary)
                                .frame(width: 9, height: 9)
                            Text(player.isRecording ? "REC \(player.recordingDurationSeconds)s" : "REC")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(player.isRecording ? Color.red.opacity(0.18) : Color.secondary.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(player.currentStation == nil)
                    .help(player.isRecording ? "Stop Recording Live Stream" : "Record Live Stream to ~/Music/FreeRadio Recordings")

                    // Sleep Timer Menu
                    Menu {
                        Text("Sleep Timer")
                        Divider()
                        Button("Off") { player.setSleepTimer(minutes: nil) }
                        Button("15 Minutes") { player.setSleepTimer(minutes: 15) }
                        Button("30 Minutes") { player.setSleepTimer(minutes: 30) }
                        Button("45 Minutes") { player.setSleepTimer(minutes: 45) }
                        Button("60 Minutes") { player.setSleepTimer(minutes: 60) }
                        Button("90 Minutes") { player.setSleepTimer(minutes: 90) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundColor(player.sleepTimerRemainingSeconds != nil ? .purple : .secondary)
                            Text(player.formattedSleepTimer ?? "Timer")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(player.sleepTimerRemainingSeconds != nil ? .purple : .secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Sleep Timer")

                    // Volume Slider
                    HStack(spacing: 6) {
                        Button {
                            player.isMuted.toggle()
                        } label: {
                            Image(systemName: player.isMuted || player.volume == 0 ? "speaker.slash.fill" : (player.volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"))
                                .font(.system(size: 14))
                                .foregroundColor(player.isMuted ? .red : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Mute")

                        Slider(value: $player.volume, in: 0...1)
                            .frame(width: 100)
                    }
                    .fixedSize()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }
}
