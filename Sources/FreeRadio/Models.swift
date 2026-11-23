import Foundation

struct RadioStation: Identifiable, Codable, Hashable {
    var id: String { stationuuid }
    let stationuuid: String
    var name: String
    var url: String
    var url_resolved: String?
    var homepage: String?
    var favicon: String?
    var tags: String?
    var country: String?
    var countrycode: String?
    var state: String?
    var language: String?
    var votes: Int?
    var codec: String?
    var bitrate: Int?
    var hls: Int?
    var lastcheckok: Int?
    var clickcount: Int?
    var clicktrend: Int?
    var isCustom: Bool?

    var streamURLString: String {
        let resolved = (url_resolved ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolved.isEmpty {
            return resolved
        }
        return url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var streamURL: URL? {
        URL(string: streamURLString)
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown Station" : trimmed
    }

    var displayCountry: String {
        let c = (country ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { return c }
        let code = (countrycode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? "Global" : code
    }

    var flagEmoji: String {
        guard let code = countrycode?.uppercased(), code.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        var s = ""
        for v in code.unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s.isEmpty ? "🌐" : s
    }

    var tagList: [String] {
        guard let tags = tags, !tags.isEmpty else { return [] }
        return tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    var displayCodec: String {
        let c = (codec ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return c.isEmpty ? "STREAM" : c
    }

    var displayBitrate: String {
        if let br = bitrate, br > 0 {
            return "\(br) kbps"
        }
        return "Variable"
    }

    static func custom(
        name: String,
        url: String,
        homepage: String = "",
        favicon: String = "",
        country: String = "Custom",
        countrycode: String = "US",
        tags: String = "custom",
        codec: String = "STREAM",
        bitrate: Int = 128
    ) -> RadioStation {
        RadioStation(
            stationuuid: "custom-\(UUID().uuidString)",
            name: name,
            url: url,
            url_resolved: url,
            homepage: homepage.isEmpty ? nil : homepage,
            favicon: favicon.isEmpty ? nil : favicon,
            tags: tags,
            country: country,
            countrycode: countrycode,
            state: nil,
            language: "english",
            votes: 0,
            codec: codec,
            bitrate: bitrate,
            hls: url.lowercased().contains(".m3u8") ? 1 : 0,
            lastcheckok: 1,
            clickcount: 0,
            clicktrend: 0,
            isCustom: true
        )
    }
}

struct CountryInfo: Identifiable, Codable, Hashable {
    var id: String { iso_3166_1 + "_" + name }
    let name: String
    let iso_3166_1: String
    let stationcount: Int

    var flagEmoji: String {
        let code = iso_3166_1.uppercased()
        guard code.count == 2 else { return "🌐" }
        let base: UInt32 = 127397
        var s = ""
        for v in code.unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s.isEmpty ? "🌐" : s
    }
}

struct TagInfo: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let stationcount: Int
}

struct LanguageInfo: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let iso_639: String?
    let stationcount: Int
}

enum NavigationSection: String, CaseIterable, Identifiable {
    case discover = "Top Voted"
    case trending = "Trending Now"
    case recentChanges = "Newly Added"
    case search = "Directory Search"
    case countries = "By Country"
    case genres = "By Genre / Tag"
    case languages = "By Language"
    case favorites = "Favorites"
    case history = "Recently Played"
    case customStations = "Custom Streams"
    case recordings = "Saved Recordings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .discover: return "star.circle.fill"
        case .trending: return "flame.fill"
        case .recentChanges: return "sparkles"
        case .search: return "magnifyingglass.circle.fill"
        case .countries: return "globe.americas.fill"
        case .genres: return "guitars.fill"
        case .languages: return "character.bubble.fill"
        case .favorites: return "heart.fill"
        case .history: return "clock.arrow.circlepath"
        case .customStations: return "antenna.radiowaves.left.and.right"
        case .recordings: return "waveform.circle.fill"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case votes = "Most Votes"
    case clickcount = "Most Popular"
    case clicktrend = "Trending"
    case bitrate = "Highest Bitrate"
    case name = "Name (A-Z)"
    case random = "Random"

    var id: String { rawValue }

    var apiOrder: String {
        switch self {
        case .votes: return "votes"
        case .clickcount: return "clickcount"
        case .clicktrend: return "clicktrend"
        case .bitrate: return "bitrate"
        case .name: return "name"
        case .random: return "random"
        }
    }

    var reverse: Bool {
        switch self {
        case .name: return false
        default: return true
        }
    }
}

struct SearchFilters: Equatable {
    var name: String = ""
    var countryCode: String = ""
    var tag: String = ""
    var language: String = ""
    var codec: String = ""
    var minBitrate: Int = 0
    var onlyVerified: Bool = true
    var hideBroken: Bool = true
    var httpsOnly: Bool = false
    var sortBy: SortOption = .votes
    var limit: Int = 250
}

struct RecordedClip: Identifiable, Hashable {
    var id: String { url.path }
    let url: URL
    let stationName: String
    let createdAt: Date
    let fileSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: createdAt)
    }
}
