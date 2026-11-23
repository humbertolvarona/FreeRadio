import Foundation

struct ServerEntry: Codable {
    let ip: String
    let name: String
}

struct ClickResponse: Codable {
    let ok: Bool?
    let message: String?
}

struct VoteResponse: Codable {
    let ok: Bool?
    let message: String?
}

struct ServerStats: Codable {
    let stations: Int?
    let stations_broken: Int?
    let tags: Int?
    let clicks_last_hour: Int?
    let clicks_last_day: Int?
    let languages: Int?
    let countries: Int?
}

actor RadioBrowserAPI {
    static let shared = RadioBrowserAPI()

    private let fallbackMirrors = [
        "https://de1.api.radio-browser.info",
        "https://fi1.api.radio-browser.info",
        "https://nl1.api.radio-browser.info",
        "https://at1.api.radio-browser.info",
        "https://fr1.api.radio-browser.info",
        "https://all.api.radio-browser.info"
    ]

    private var activeMirrors: [String] = []
    private var currentMirrorIndex: Int = 0
    private let userAgent = "FreeRadioMacOS/2.0 (macOS; American-English)"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 25
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
        self.activeMirrors = fallbackMirrors
    }

    func refreshMirrors() async -> [String] {
        guard let url = URL(string: "https://all.api.radio-browser.info/json/servers") else {
            return activeMirrors
        }
        do {
            let (data, _) = try await session.data(from: url)
            let entries = try JSONDecoder().decode([ServerEntry].self, from: data)
            let uniqueNames = Array(Set(entries.map { "https://\($0.name)" })).sorted()
            if !uniqueNames.isEmpty {
                activeMirrors = uniqueNames
                currentMirrorIndex = 0
            }
        } catch {
            if activeMirrors.isEmpty {
                activeMirrors = fallbackMirrors
            }
        }
        return activeMirrors
    }

    func currentMirror() -> String {
        guard !activeMirrors.isEmpty else { return fallbackMirrors[0] }
        return activeMirrors[currentMirrorIndex % activeMirrors.count]
    }

    func switchMirror() -> String {
        guard !activeMirrors.isEmpty else { return fallbackMirrors[0] }
        currentMirrorIndex = (currentMirrorIndex + 1) % activeMirrors.count
        return currentMirror()
    }

    private func request<T: Decodable>(path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var lastError: Error = URLError(.cannotConnectToHost)
        let mirrorsToTry = activeMirrors.isEmpty ? fallbackMirrors : activeMirrors

        for attempt in 0..<min(mirrorsToTry.count, 4) {
            let mirror = mirrorsToTry[(currentMirrorIndex + attempt) % mirrorsToTry.count]
            var components = URLComponents(string: mirror + path)
            if !queryItems.isEmpty {
                components?.queryItems = queryItems
            }
            guard let url = components?.url else { continue }

            var req = URLRequest(url: url)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await session.data(for: req)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    currentMirrorIndex = (currentMirrorIndex + attempt) % mirrorsToTry.count
                    return try JSONDecoder().decode(T.self, from: data)
                } else {
                    lastError = URLError(.badServerResponse)
                }
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    func fetchServerStats() async throws -> ServerStats {
        try await request(path: "/json/stats")
    }

    func fetchTopVoted(limit: Int = 200, offset: Int = 0) async throws -> [RadioStation] {
        try await request(
            path: "/json/stations/topvote/\(limit)",
            queryItems: [
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    func fetchTrending(limit: Int = 200, offset: Int = 0) async throws -> [RadioStation] {
        try await request(
            path: "/json/stations/topclick/\(limit)",
            queryItems: [
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    func fetchRecentChanges(limit: Int = 200) async throws -> [RadioStation] {
        try await request(
            path: "/json/stations/lastchange/\(limit)",
            queryItems: [
                URLQueryItem(name: "hidebroken", value: "true")
            ]
        )
    }

    func searchStations(filters: SearchFilters, offset: Int = 0) async throws -> [RadioStation] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(filters.limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "order", value: filters.sortBy.apiOrder),
            URLQueryItem(name: "reverse", value: filters.sortBy.reverse ? "true" : "false"),
            URLQueryItem(name: "hidebroken", value: filters.hideBroken ? "true" : "false")
        ]

        let trimmedName = filters.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            items.append(URLQueryItem(name: "name", value: trimmedName))
        }
        if !filters.countryCode.isEmpty {
            items.append(URLQueryItem(name: "countrycode", value: filters.countryCode))
        }
        let trimmedTag = filters.tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty {
            items.append(URLQueryItem(name: "tag", value: trimmedTag))
        }
        let trimmedLang = filters.language.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLang.isEmpty {
            items.append(URLQueryItem(name: "language", value: trimmedLang))
        }
        if !filters.codec.isEmpty {
            items.append(URLQueryItem(name: "codec", value: filters.codec))
        }
        if filters.minBitrate > 0 {
            items.append(URLQueryItem(name: "bitrateMin", value: "\(filters.minBitrate)"))
        }
        if filters.httpsOnly {
            items.append(URLQueryItem(name: "is_https", value: "true"))
        }

        return try await request(path: "/json/stations/search", queryItems: items)
    }

    func fetchCountries() async throws -> [CountryInfo] {
        let countries: [CountryInfo] = try await request(
            path: "/json/countries",
            queryItems: [
                URLQueryItem(name: "order", value: "stationcount"),
                URLQueryItem(name: "reverse", value: "true"),
                URLQueryItem(name: "hidebroken", value: "true")
            ]
        )
        var seen = Set<String>()
        var result: [CountryInfo] = []
        for c in countries where c.stationcount > 0 && !c.iso_3166_1.isEmpty {
            let key = c.iso_3166_1.uppercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(c)
            }
        }
        return result
    }

    func fetchTags(limit: Int = 250) async throws -> [TagInfo] {
        let tags: [TagInfo] = try await request(
            path: "/json/tags",
            queryItems: [
                URLQueryItem(name: "order", value: "stationcount"),
                URLQueryItem(name: "reverse", value: "true"),
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return tags.filter { $0.stationcount > 5 && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func fetchLanguages(limit: Int = 200) async throws -> [LanguageInfo] {
        let langs: [LanguageInfo] = try await request(
            path: "/json/languages",
            queryItems: [
                URLQueryItem(name: "order", value: "stationcount"),
                URLQueryItem(name: "reverse", value: "true"),
                URLQueryItem(name: "hidebroken", value: "true"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return langs.filter { $0.stationcount > 3 && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func registerClick(stationUUID: String) async {
        guard !stationUUID.hasPrefix("custom-") else { return }
        _ = try? await request(path: "/json/url/\(stationUUID)") as ClickResponse
    }

    func voteForStation(stationUUID: String) async -> String {
        guard !stationUUID.hasPrefix("custom-") else {
            return "Custom streams cannot be voted on the global directory."
        }
        do {
            let res: VoteResponse = try await request(path: "/json/vote/\(stationUUID)")
            return res.message ?? "Vote registered!"
        } catch {
            return "Could not submit vote: \(error.localizedDescription)"
        }
    }
}
