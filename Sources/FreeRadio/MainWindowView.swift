import SwiftUI
import AppKit

struct MainWindowView: View {
    @ObservedObject var store: RadioStore
    @ObservedObject var player: AudioPlayerManager
    @State private var quickSearchQuery: String = ""

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 260)
        } detail: {
            VStack(spacing: 0) {
                topHeaderBar

                if let banner = store.statusBannerMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(banner)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Button("Dismiss") {
                            store.statusBannerMessage = nil
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                }

                if store.selectedSection == .recordings {
                    RecordingsListView(player: player)
                } else {
                    mainContentArea
                }

                NowPlayingDockView(store: store, player: player)
            }
            .frame(minWidth: 960)
        }
        .sheet(item: $store.inspectedStation) { station in
            StationDetailSheet(station: station, store: store, player: player)
        }
        .sheet(isPresented: $store.showAddCustomStationSheet) {
            AddCustomStationSheet(store: store)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $store.selectedSection) {
            Section("Global Radio Directory") {
                sidebarItem(.discover)
                sidebarItem(.trending)
                sidebarItem(.recentChanges)
                sidebarItem(.search)
            }

            Section("Browse Categories") {
                sidebarItem(.countries, badgeCount: store.countries.count)
                sidebarItem(.genres, badgeCount: store.tags.count)
                sidebarItem(.languages, badgeCount: store.languages.count)
            }

            Section("Your Library") {
                sidebarItem(.favorites, badgeCount: store.favorites.count)
                sidebarItem(.history, badgeCount: store.history.count)
                sidebarItem(.customStations, badgeCount: store.customStations.count)
                sidebarItem(.recordings, badgeCount: player.recordedClips.count)
            }

            if let stats = store.globalStats {
                Section("Directory Status") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("Online Stations: \((stats.stations ?? 0).formatted())")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text("Countries: \((stats.countries ?? 0).formatted()) • Tags: \((stats.tags ?? 0).formatted())")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("Server: \(store.activeMirrorServer.replacingOccurrences(of: "https://", with: ""))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func sidebarItem(_ section: NavigationSection, badgeCount: Int = 0) -> some View {
        HStack {
            Label(section.rawValue, systemImage: section.icon)
                .lineLimit(1)
            Spacer(minLength: 4)
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.18))
                    .clipShape(Capsule())
            }
        }
        .tag(section)
    }

    // MARK: - Top Header Bar (Search & Refresh Stations)

    private var topHeaderBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedSection.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("\(store.displayedStations.count) stations available")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Spacer(minLength: 8)

                // Quick Global Search to Update Stations from Online Directory
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search & update stations (Jazz, BBC, NPR, Rock)...", text: $quickSearchQuery)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 180, idealWidth: 250, maxWidth: 340)
                        .onSubmit {
                            Task {
                                await store.quickUpdateStationsByQuery(quickSearchQuery)
                            }
                        }
                    if !quickSearchQuery.isEmpty {
                        Button {
                            quickSearchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Search & Update") {
                        Task {
                            await store.quickUpdateStationsByQuery(quickSearchQuery)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )

                // Instant Filter in Current View
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.secondary)
                    TextField("Filter view...", text: $store.localFilterText)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 90, idealWidth: 115, maxWidth: 150)
                    if !store.localFilterText.isEmpty {
                        Button {
                            store.localFilterText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                )

                // Action Buttons (always visible & fixed size)
                HStack(spacing: 8) {
                    Button {
                        Task {
                            await store.loadCurrentSection(forceRefresh: true)
                            store.showBanner("Refreshed station list from live directory.")
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .fixedSize()
                    .help("Reload and update stations from live directory")

                    Button {
                        store.showAddCustomStationSheet = true
                    } label: {
                        Label("Add Stream", systemImage: "plus")
                    }
                    .fixedSize()
                    .help("Add a custom radio stream URL")

                    if store.selectedSection == .favorites {
                        Menu {
                            Button {
                                store.exportFavoritesAsM3U()
                            } label: {
                                Label("Export Favorites as M3U Playlist...", systemImage: "music.note.list")
                            }
                            Button {
                                store.exportFavoritesAsJSON()
                            } label: {
                                Label("Export Favorites as JSON Backup...", systemImage: "square.and.arrow.up")
                            }
                            Divider()
                            Button {
                                store.importFavoritesFromJSON()
                            } label: {
                                Label("Import Favorites from JSON...", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Label("Import / Export", systemImage: "arrow.up.arrow.down.circle")
                        }
                        .fixedSize()
                    }

                    if store.selectedSection == .history && !store.history.isEmpty {
                        Button(role: .destructive) {
                            store.clearHistory()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if store.selectedSection == .search {
                advancedSearchFilterBar
            }

            Divider()
        }
        .background(.bar)
    }

    // MARK: - Advanced Directory Search Bar

    private var advancedSearchFilterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Name:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    TextField("Station name...", text: $store.searchFilters.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 130, maxWidth: 190)
                        .onSubmit {
                            Task { await store.performDirectorySearch() }
                        }
                }

                HStack(spacing: 4) {
                    Text("Genre/Tag:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    TextField("e.g. jazz, news, 80s", text: $store.searchFilters.tag)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 120, maxWidth: 180)
                        .onSubmit {
                            Task { await store.performDirectorySearch() }
                        }
                }

                HStack(spacing: 4) {
                    Text("Country:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    Picker("", selection: $store.searchFilters.countryCode) {
                        Text("All Countries").tag("")
                        ForEach(store.countries) { c in
                            Text("\(c.flagEmoji) \(c.name)").tag(c.iso_3166_1)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 165)
                }

                HStack(spacing: 4) {
                    Text("Language:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    TextField("e.g. english, spanish", text: $store.searchFilters.language)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 115, maxWidth: 165)
                        .onSubmit {
                            Task { await store.performDirectorySearch() }
                        }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text("Codec:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    Picker("", selection: $store.searchFilters.codec) {
                        Text("Any").tag("")
                        Text("MP3").tag("MP3")
                        Text("AAC").tag("AAC")
                        Text("AAC+").tag("AAC+")
                        Text("OGG").tag("OGG")
                        Text("FLAC").tag("FLAC")
                    }
                    .labelsHidden()
                    .frame(width: 90)
                }

                HStack(spacing: 4) {
                    Text("Min Bitrate:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    Picker("", selection: $store.searchFilters.minBitrate) {
                        Text("Any").tag(0)
                        Text("64+ kbps").tag(64)
                        Text("128+ kbps").tag(128)
                        Text("192+ kbps").tag(192)
                        Text("256+ kbps").tag(256)
                        Text("320 kbps").tag(320)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                HStack(spacing: 4) {
                    Text("Sort By:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                    Picker("", selection: $store.searchFilters.sortBy) {
                        ForEach(SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 145)
                }

                Toggle("HTTPS Only", isOn: $store.searchFilters.httpsOnly)
                    .font(.system(size: 11))
                    .fixedSize()

                Toggle("Hide Broken", isOn: $store.searchFilters.hideBroken)
                    .font(.system(size: 11))
                    .fixedSize()

                Spacer(minLength: 4)

                Button("Reset Filters") {
                    store.searchFilters = SearchFilters()
                    Task { await store.performDirectorySearch() }
                }
                .controlSize(.small)
                .fixedSize()

                Button {
                    Task { await store.performDirectorySearch() }
                } label: {
                    Label("Update Stations Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Main Content Area

    @ViewBuilder
    private var mainContentArea: some View {
        switch store.selectedSection {
        case .countries:
            HSplitView {
                countrySelectorList
                    .frame(minWidth: 210, idealWidth: 235, maxWidth: 290)
                stationListView
            }
        case .genres:
            HSplitView {
                genreSelectorList
                    .frame(minWidth: 200, idealWidth: 225, maxWidth: 280)
                stationListView
            }
        case .languages:
            HSplitView {
                languageSelectorList
                    .frame(minWidth: 200, idealWidth: 225, maxWidth: 280)
                stationListView
            }
        default:
            stationListView
        }
    }

    private var countrySelectorList: some View {
        List(store.countries, selection: $store.selectedCountry) { country in
            HStack {
                Text(country.flagEmoji)
                Text(country.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
                Text("\(country.stationcount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .tag(country)
        }
    }

    private var genreSelectorList: some View {
        List(store.tags, selection: $store.selectedTag) { tag in
            HStack {
                Text("#\(tag.name)")
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
                Text("\(tag.stationcount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .tag(tag)
        }
    }

    private var languageSelectorList: some View {
        List(store.languages, selection: $store.selectedLanguage) { lang in
            HStack {
                Text(lang.name.capitalized)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer()
                Text("\(lang.stationcount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .tag(lang)
        }
    }

    private var stationListView: some View {
        ZStack {
            if store.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Fetching live stations from global directory...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.displayedStations.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(store.displayedStations) { station in
                        StationRowView(station: station, store: store, player: player)
                            .listRowSeparator(.visible)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: store.selectedSection == .favorites ? "heart.circle" : "radio")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            if store.selectedSection == .favorites {
                Text("No Favorite Stations Yet")
                    .font(.system(size: 17, weight: .bold))
                Text("Click the heart icon next to any radio station while browsing or searching to save it to your Favorites.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                Button("Explore Top Voted Stations") {
                    store.selectedSection = .discover
                }
                .buttonStyle(.borderedProminent)
            } else if store.selectedSection == .customStations {
                Text("No Custom Streams Added")
                    .font(.system(size: 17, weight: .bold))
                Text("Add your own MP3, AAC, OGG, or HLS (.m3u8) stream URLs to listen anytime.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Button("Add Custom Stream URL") {
                    store.showAddCustomStationSheet = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No Stations Found")
                    .font(.system(size: 17, weight: .bold))
                Text("Try updating your search filters, switching directory mirrors, or refreshing the list.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    Button("Refresh Directory") {
                        Task { await store.loadCurrentSection(forceRefresh: true) }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Switch API Mirror") {
                        Task { await store.switchMirrorAndReload() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
