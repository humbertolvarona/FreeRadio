import Foundation
import AppKit
import Combine

@MainActor
final class RadioStore: ObservableObject {
    @Published var selectedSection: NavigationSection = .discover {
        didSet {
            localFilterText = ""
            Task { await loadCurrentSection() }
        }
    }

    @Published var stations: [RadioStation] = []
    @Published var favorites: [RadioStation] = []
    @Published var history: [RadioStation] = []
    @Published var customStations: [RadioStation] = []

    @Published var countries: [CountryInfo] = []
    @Published var tags: [TagInfo] = []
    @Published var languages: [LanguageInfo] = []

    @Published var selectedCountry: CountryInfo? {
        didSet {
            if let country = selectedCountry {
                searchFilters.countryCode = country.iso_3166_1
                Task { await fetchStationsByCountry(country) }
            }
        }
    }

    @Published var selectedTag: TagInfo? {
        didSet {
            if let tag = selectedTag {
                searchFilters.tag = tag.name
                Task { await fetchStationsByTag(tag) }
            }
        }
    }

    @Published var selectedLanguage: LanguageInfo? {
        didSet {
            if let lang = selectedLanguage {
                searchFilters.language = lang.name
                Task { await fetchStationsByLanguage(lang) }
            }
        }
    }

    @Published var searchFilters = SearchFilters()
    @Published var localFilterText: String = ""
    @Published var isLoading: Bool = false
    @Published var statusBannerMessage: String? = nil
    @Published var activeMirrorServer: String = "https://de1.api.radio-browser.info"
    @Published var globalStats: ServerStats? = nil
    @Published var inspectedStation: RadioStation? = nil
    @Published var showAddCustomStationSheet: Bool = false

    private let favoritesKey = "FreeRadio.favorites.v2"
    private let historyKey = "FreeRadio.history.v2"
    private let customStationsKey = "FreeRadio.customStations.v2"

    init() {
        loadPersistedData()
        Task {
            await initializeDirectory()
        }
    }

    func initializeDirectory() async {
        let mirrors = await RadioBrowserAPI.shared.refreshMirrors()
        if let first = mirrors.first {
            activeMirrorServer = first
        }
        async let statsTask: Void = loadServerStats()
        async let sectionTask: Void = loadCurrentSection()
        async let metaTask: Void = preloadMetadataCatalogs()
        _ = await (statsTask, sectionTask, metaTask)
    }

    func loadServerStats() async {
        if let stats = try? await RadioBrowserAPI.shared.fetchServerStats() {
            self.globalStats = stats
        }
    }

    func preloadMetadataCatalogs() async {
        if countries.isEmpty {
            if let c = try? await RadioBrowserAPI.shared.fetchCountries() {
                countries = c
            }
        }
        if tags.isEmpty {
            if let t = try? await RadioBrowserAPI.shared.fetchTags() {
                tags = t
            }
        }
        if languages.isEmpty {
            if let l = try? await RadioBrowserAPI.shared.fetchLanguages() {
                languages = l
            }
        }
    }

    func switchMirrorAndReload() async {
        activeMirrorServer = await RadioBrowserAPI.shared.switchMirror()
        showBanner("Switched directory mirror to \(activeMirrorServer)")
        await loadServerStats()
        await loadCurrentSection(forceRefresh: true)
    }

    func loadCurrentSection(forceRefresh: Bool = false) async {
        switch selectedSection {
        case .discover:
            await fetchTopVoted()
        case .trending:
            await fetchTrending()
        case .recentChanges:
            await fetchRecentChanges()
        case .search:
            await performDirectorySearch()
        case .countries:
            if countries.isEmpty || forceRefresh {
                isLoading = true
                countries = (try? await RadioBrowserAPI.shared.fetchCountries()) ?? []
                isLoading = false
            }
            if let selected = selectedCountry ?? countries.first {
                if selectedCountry == nil {
                    selectedCountry = selected
                } else {
                    await fetchStationsByCountry(selected)
                }
            }
        case .genres:
            if tags.isEmpty || forceRefresh {
                isLoading = true
                tags = (try? await RadioBrowserAPI.shared.fetchTags()) ?? []
                isLoading = false
            }
            if let selected = selectedTag ?? tags.first {
                if selectedTag == nil {
                    selectedTag = selected
                } else {
                    await fetchStationsByTag(selected)
                }
            }
        case .languages:
            if languages.isEmpty || forceRefresh {
                isLoading = true
                languages = (try? await RadioBrowserAPI.shared.fetchLanguages()) ?? []
                isLoading = false
            }
            if let selected = selectedLanguage ?? languages.first {
                if selectedLanguage == nil {
                    selectedLanguage = selected
                } else {
                    await fetchStationsByLanguage(selected)
                }
            }
        case .favorites:
            stations = favorites
        case .history:
            stations = history
        case .customStations:
            stations = customStations
        case .recordings:
            AudioPlayerManager.shared.refreshRecordingsList()
        }
    }

    func fetchTopVoted() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await RadioBrowserAPI.shared.fetchTopVoted(limit: 250)
        } catch {
            showBanner("Could not fetch top stations: \(error.localizedDescription)")
        }
    }

    func fetchTrending() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await RadioBrowserAPI.shared.fetchTrending(limit: 250)
        } catch {
            showBanner("Could not fetch trending stations: \(error.localizedDescription)")
        }
    }

    func fetchRecentChanges() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await RadioBrowserAPI.shared.fetchRecentChanges(limit: 250)
        } catch {
            showBanner("Could not fetch newly added stations: \(error.localizedDescription)")
        }
    }

    func performDirectorySearch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let results = try await RadioBrowserAPI.shared.searchStations(filters: searchFilters)
            stations = results
            showBanner("Updated directory: \(results.count) stations found.")
        } catch {
            showBanner("Search failed: \(error.localizedDescription)")
        }
    }

    func quickUpdateStationsByQuery(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchFilters.name = trimmed
        if selectedSection != .search {
            selectedSection = .search
        } else {
            await performDirectorySearch()
        }
    }

    func fetchStationsByCountry(_ country: CountryInfo) async {
        isLoading = true
        defer { isLoading = false }
        var f = SearchFilters()
        f.countryCode = country.iso_3166_1
        f.sortBy = .votes
        f.limit = 250
        do {
            stations = try await RadioBrowserAPI.shared.searchStations(filters: f)
        } catch {
            showBanner("Failed loading stations for \(country.name)")
        }
    }

    func fetchStationsByTag(_ tag: TagInfo) async {
        isLoading = true
        defer { isLoading = false }
        var f = SearchFilters()
        f.tag = tag.name
        f.sortBy = .votes
        f.limit = 250
        do {
            stations = try await RadioBrowserAPI.shared.searchStations(filters: f)
        } catch {
            showBanner("Failed loading stations for #\(tag.name)")
        }
    }

    func fetchStationsByLanguage(_ lang: LanguageInfo) async {
        isLoading = true
        defer { isLoading = false }
        var f = SearchFilters()
        f.language = lang.name
        f.sortBy = .votes
        f.limit = 250
        do {
            stations = try await RadioBrowserAPI.shared.searchStations(filters: f)
        } catch {
            showBanner("Failed loading stations in \(lang.name.capitalized)")
        }
    }

    var displayedStations: [RadioStation] {
        let base: [RadioStation]
        switch selectedSection {
        case .favorites:
            base = favorites
        case .history:
            base = history
        case .customStations:
            base = customStations
        default:
            base = stations
        }

        let query = localFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }

        return base.filter { st in
            st.displayName.lowercased().contains(query) ||
            st.displayCountry.lowercased().contains(query) ||
            (st.tags?.lowercased().contains(query) ?? false) ||
            (st.language?.lowercased().contains(query) ?? false) ||
            st.displayCodec.lowercased().contains(query)
        }
    }

    // MARK: - Playback & Surprise Me

    func playStation(_ station: RadioStation) {
        AudioPlayerManager.shared.play(station: station)
        addToHistory(station)
    }

    func playRandomStation() {
        let pool = displayedStations.isEmpty ? stations : displayedStations
        if let random = pool.randomElement() {
            playStation(random)
            showBanner("Tuned in to random station: \(random.displayName)")
        }
    }

    func playNextStation() {
        let list = displayedStations
        guard !list.isEmpty else { return }
        if let current = AudioPlayerManager.shared.currentStation,
           let idx = list.firstIndex(where: { $0.stationuuid == current.stationuuid }) {
            let nextIdx = (idx + 1) % list.count
            playStation(list[nextIdx])
        } else if let first = list.first {
            playStation(first)
        }
    }

    func playPreviousStation() {
        let list = displayedStations
        guard !list.isEmpty else { return }
        if let current = AudioPlayerManager.shared.currentStation,
           let idx = list.firstIndex(where: { $0.stationuuid == current.stationuuid }) {
            let prevIdx = (idx - 1 + list.count) % list.count
            playStation(list[prevIdx])
        } else if let first = list.first {
            playStation(first)
        }
    }

    // MARK: - Favorites Management

    func isFavorite(_ station: RadioStation) -> Bool {
        favorites.contains(where: { $0.stationuuid == station.stationuuid })
    }

    func toggleFavorite(_ station: RadioStation) {
        if let index = favorites.firstIndex(where: { $0.stationuuid == station.stationuuid }) {
            favorites.remove(at: index)
            showBanner("Removed \"\(station.displayName)\" from Favorites.")
        } else {
            favorites.insert(station, at: 0)
            showBanner("Added \"\(station.displayName)\" to Favorites.")
        }
        saveFavorites()
        if selectedSection == .favorites {
            stations = favorites
        }
    }

    // MARK: - Custom Stations

    func addCustomStation(
        name: String,
        streamURL: String,
        homepage: String,
        favicon: String,
        country: String,
        tags: String,
        codec: String,
        bitrate: Int
    ) {
        let station = RadioStation.custom(
            name: name,
            url: streamURL,
            homepage: homepage,
            favicon: favicon,
            country: country.isEmpty ? "Custom" : country,
            tags: tags.isEmpty ? "custom" : tags,
            codec: codec.isEmpty ? "STREAM" : codec,
            bitrate: bitrate
        )
        customStations.insert(station, at: 0)
        favorites.insert(station, at: 0)
        saveCustomStations()
        saveFavorites()
        if selectedSection == .customStations {
            stations = customStations
        }
        showBanner("Added custom stream \"\(station.displayName)\" and saved to Favorites.")
    }

    func deleteCustomStation(_ station: RadioStation) {
        customStations.removeAll { $0.stationuuid == station.stationuuid }
        saveCustomStations()
        if selectedSection == .customStations {
            stations = customStations
        }
    }

    // MARK: - History

    private func addToHistory(_ station: RadioStation) {
        history.removeAll { $0.stationuuid == station.stationuuid }
        history.insert(station, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        saveHistory()
        if selectedSection == .history {
            stations = history
        }
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
        if selectedSection == .history {
            stations = []
        }
        showBanner("Cleared playback history.")
    }

    // MARK: - Voting

    func voteForStation(_ station: RadioStation) {
        Task {
            let msg = await RadioBrowserAPI.shared.voteForStation(stationUUID: station.stationuuid)
            showBanner(msg)
        }
    }

    // MARK: - Import / Export Favorites (M3U & JSON)

    func exportFavoritesAsM3U() {
        let panel = NSSavePanel()
        panel.title = "Export Favorites Playlist (.m3u)"
        panel.nameFieldStringValue = "FreeRadio-Favorites.m3u"
        panel.allowedContentTypes = [.m3uPlaylist, .plainText]

        if panel.runModal() == .OK, let url = panel.url {
            var lines = ["#EXTM3U"]
            for st in favorites {
                lines.append("#EXTINF:-1 tvg-logo=\"\(st.favicon ?? "")\" group-title=\"\(st.displayCountry)\",\(st.displayName)")
                lines.append(st.streamURLString)
            }
            let content = lines.joined(separator: "\n")
            try? content.write(to: url, atomically: true, encoding: .utf8)
            showBanner("Exported \(favorites.count) favorites to \(url.lastPathComponent)")
        }
    }

    func exportFavoritesAsJSON() {
        let panel = NSSavePanel()
        panel.title = "Export Favorites Backup (.json)"
        panel.nameFieldStringValue = "FreeRadio-Favorites.json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(favorites) {
                try? data.write(to: url)
                showBanner("Exported \(favorites.count) favorites to \(url.lastPathComponent)")
            }
        }
    }

    func importFavoritesFromJSON() {
        let panel = NSOpenPanel()
        panel.title = "Import Favorites Backup (.json)"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url),
               let imported = try? JSONDecoder().decode([RadioStation].self, from: data) {
                var addedCount = 0
                for st in imported {
                    if !favorites.contains(where: { $0.stationuuid == st.stationuuid }) {
                        favorites.append(st)
                        addedCount += 1
                    }
                }
                saveFavorites()
                if selectedSection == .favorites {
                    stations = favorites
                }
                showBanner("Imported \(addedCount) new stations into Favorites.")
            } else {
                showBanner("Failed to parse JSON favorites file.")
            }
        }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            favorites = decoded
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            history = decoded
        }
        if let data = UserDefaults.standard.data(forKey: customStationsKey),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            customStations = decoded
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func saveCustomStations() {
        if let data = try? JSONEncoder().encode(customStations) {
            UserDefaults.standard.set(data, forKey: customStationsKey)
        }
    }

    func showBanner(_ message: String) {
        statusBannerMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if statusBannerMessage == message {
                statusBannerMessage = nil
            }
        }
    }
}
