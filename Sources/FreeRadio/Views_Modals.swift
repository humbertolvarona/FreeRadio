import SwiftUI
import AppKit

struct StationDetailSheet: View {
    let station: RadioStation
    @ObservedObject var store: RadioStore
    @ObservedObject var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 72, height: 72)

                    if let fav = station.favicon, let url = URL(string: fav), !fav.isEmpty {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            } else {
                                Text(station.flagEmoji).font(.system(size: 34))
                            }
                        }
                    } else {
                        Text(station.flagEmoji).font(.system(size: 34))
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(station.displayName)
                        .font(.system(size: 20, weight: .bold))
                    Text("\(station.flagEmoji) \(station.displayCountry) \(station.state != nil && !station.state!.isEmpty ? "• \(station.state!)" : "")")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Label(station.displayCodec, systemImage: "waveform")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())

                        Label(station.displayBitrate, systemImage: "speedometer")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(Capsule())

                        if let votes = station.votes {
                            Label("\(votes) Votes", systemImage: "hand.thumbsup.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Station UUID:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(station.stationuuid)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                }

                GridRow {
                    Text("Direct Stream URL:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    HStack {
                        Text(station.streamURLString)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(2)
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(station.streamURLString, forType: .string)
                            store.showBanner("Copied stream URL to clipboard.")
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.system(size: 11))
                        }
                    }
                }

                if let homepage = station.homepage, !homepage.isEmpty {
                    GridRow {
                        Text("Official Website:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack {
                            Text(homepage)
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                            if let url = URL(string: homepage) {
                                Button("Open in Browser") {
                                    NSWorkspace.shared.open(url)
                                }
                                .font(.system(size: 11))
                            }
                        }
                    }
                }

                if let lang = station.language, !lang.isEmpty {
                    GridRow {
                        Text("Broadcast Language:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(lang.capitalized)
                            .font(.system(size: 12))
                    }
                }

                if let clicks = station.clickcount {
                    GridRow {
                        Text("Recent Listeners:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("\(clicks) clicks (24h trend: \(station.clicktrend ?? 0))")
                            .font(.system(size: 12))
                    }
                }

                if !station.tagList.isEmpty {
                    GridRow {
                        Text("Genres & Tags:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(station.tagList, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    store.playStation(station)
                } label: {
                    Label("Play Stream Now", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.toggleFavorite(station)
                } label: {
                    Label(
                        store.isFavorite(station) ? "Remove from Favorites" : "Add to Favorites",
                        systemImage: store.isFavorite(station) ? "heart.slash.fill" : "heart.fill"
                    )
                }

                Button {
                    store.voteForStation(station)
                } label: {
                    Label("Vote for Station", systemImage: "hand.thumbsup")
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 600)
    }
}

struct AddCustomStationSheet: View {
    @ObservedObject var store: RadioStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var streamURL: String = ""
    @State private var homepage: String = ""
    @State private var favicon: String = ""
    @State private var country: String = "United States"
    @State private var tags: String = "music, live"
    @State private var codec: String = "MP3"
    @State private var bitrate: Int = 128

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (streamURL.lowercased().hasPrefix("http://") || streamURL.lowercased().hasPrefix("https://"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Custom Radio Stream")
                        .font(.system(size: 18, weight: .bold))
                    Text("Tune in to any direct MP3, AAC, OGG, or HLS (.m3u8) stream URL and save it to your library.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Form {
                TextField("Station Name *", text: $name, prompt: Text("e.g., SomaFM Groove Salad"))
                TextField("Stream URL (HTTP/HTTPS) *", text: $streamURL, prompt: Text("https://ice2.somafm.com/groovesalad-128-mp3"))
                TextField("Website URL (Optional)", text: $homepage, prompt: Text("https://somafm.com"))
                TextField("Logo / Favicon URL (Optional)", text: $favicon, prompt: Text("https://somafm.com/img3/groovesalad-400.jpg"))
                TextField("Country", text: $country, prompt: Text("United States"))
                TextField("Tags (comma-separated)", text: $tags, prompt: Text("ambient, chillout, electronic"))

                HStack {
                    Picker("Codec", selection: $codec) {
                        Text("MP3").tag("MP3")
                        Text("AAC").tag("AAC")
                        Text("AAC+").tag("AAC+")
                        Text("OGG").tag("OGG")
                        Text("HLS").tag("HLS")
                        Text("FLAC").tag("FLAC")
                    }
                    .frame(width: 180)

                    Picker("Bitrate", selection: $bitrate) {
                        Text("64 kbps").tag(64)
                        Text("96 kbps").tag(96)
                        Text("128 kbps").tag(128)
                        Text("192 kbps").tag(192)
                        Text("256 kbps").tag(256)
                        Text("320 kbps").tag(320)
                    }
                    .frame(width: 180)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    store.addCustomStation(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        streamURL: streamURL.trimmingCharacters(in: .whitespacesAndNewlines),
                        homepage: homepage.trimmingCharacters(in: .whitespacesAndNewlines),
                        favicon: favicon.trimmingCharacters(in: .whitespacesAndNewlines),
                        country: country.trimmingCharacters(in: .whitespacesAndNewlines),
                        tags: tags.trimmingCharacters(in: .whitespacesAndNewlines),
                        codec: codec,
                        bitrate: bitrate
                    )
                    dismiss()
                } label: {
                    Label("Save & Add to Favorites", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540, height: 470)
    }
}

struct RecordingsListView: View {
    @ObservedObject var player: AudioPlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved Stream Recordings")
                        .font(.system(size: 18, weight: .bold))
                    Text("Recordings are saved directly to \(player.recordingsDirectory.path)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    NSWorkspace.shared.open(player.recordingsDirectory)
                } label: {
                    Label("Open Recordings Folder in Finder", systemImage: "folder")
                }
                Button {
                    player.refreshRecordingsList()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            if player.recordedClips.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Stream Recordings Yet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("While listening to any live radio station, click the 'REC' button in the bottom player bar to capture the live audio stream.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(player.recordedClips) { clip in
                        HStack(spacing: 12) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(clip.stationName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(clip.formattedDate) • \(clip.formattedSize)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([clip.url])
                            } label: {
                                Label("Reveal in Finder", systemImage: "magnifyingglass")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                NSWorkspace.shared.open(clip.url)
                            } label: {
                                Label("Play File", systemImage: "play.fill")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive) {
                                player.deleteRecording(clip)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete Recording")
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }
}
