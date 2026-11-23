import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class StreamRecorderDelegate: NSObject, URLSessionDataDelegate {
    private var fileHandle: FileHandle?
    private let onBytesReceived: (Int64) -> Void

    init(fileURL: URL, onBytesReceived: @escaping (Int64) -> Void) throws {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        self.fileHandle = try FileHandle(forWritingTo: fileURL)
        self.onBytesReceived = onBytesReceived
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        try? fileHandle?.write(contentsOf: data)
        onBytesReceived(Int64(data.count))
    }

    func close() {
        try? fileHandle?.close()
        fileHandle = nil
    }
}

@MainActor
final class AudioPlayerManager: NSObject, ObservableObject, AVPlayerItemMetadataOutputPushDelegate {
    static let shared = AudioPlayerManager()

    @Published var currentStation: RadioStation?
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var volume: Float = 0.85 {
        didSet {
            player?.volume = isMuted ? 0 : volume
            UserDefaults.standard.set(volume, forKey: "FreeRadio.volume")
        }
    }
    @Published var isMuted: Bool = false {
        didSet {
            player?.volume = isMuted ? 0 : volume
        }
    }
    @Published var liveMetadataTitle: String = ""
    @Published var errorMessage: String?
    @Published var visualizerLevels: [CGFloat] = Array(repeating: 0.15, count: 16)

    // Sleep Timer
    @Published var sleepTimerRemainingSeconds: Int? = nil
    private var sleepTimer: Timer?

    // Live Stream Recording
    @Published var isRecording: Bool = false
    @Published var recordingBytes: Int64 = 0
    @Published var recordingDurationSeconds: Int = 0
    @Published var recordedClips: [RecordedClip] = []
    private var recordingSession: URLSession?
    private var recordingTask: URLSessionDataTask?
    private var recordingDelegate: StreamRecorderDelegate?
    private var recordingTimer: Timer?

    private var player: AVPlayer?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var visualizerTimer: Timer?

    override init() {
        super.init()
        let savedVol = UserDefaults.standard.object(forKey: "FreeRadio.volume") as? Float
        self.volume = savedVol ?? 0.85
        setupRemoteTransportControls()
        startVisualizerTimer()
        refreshRecordingsList()
    }

    func play(station: RadioStation) {
        errorMessage = nil
        if isRecording {
            stopRecording()
        }

        guard let url = station.streamURL else {
            errorMessage = "Invalid stream URL for \(station.displayName)"
            return
        }

        currentStation = station
        liveMetadataTitle = ""
        isBuffering = true

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metadataOutput.setDelegate(self, queue: DispatchQueue.main)
        item.add(metadataOutput)

        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: item)
        }

        player?.volume = isMuted ? 0 : volume

        observePlayerItem(item)
        observePlayer()

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()

        Task {
            await RadioBrowserAPI.shared.registerClick(stationUUID: station.stationuuid)
        }
    }

    func togglePlayPause() {
        guard let station = currentStation else { return }
        if isPlaying {
            pause()
        } else {
            play(station: station)
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        isBuffering = false
        if isRecording {
            stopRecording()
        }
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        isBuffering = false
        liveMetadataTitle = ""
        if isRecording {
            stopRecording()
        }
        updateNowPlayingInfo()
    }

    private func observePlayerItem(_ item: AVPlayerItem) {
        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] observedItem, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch observedItem.status {
                case .readyToPlay:
                    self.errorMessage = nil
                case .failed:
                    self.isPlaying = false
                    self.isBuffering = false
                    self.errorMessage = observedItem.error?.localizedDescription ?? "Stream failed to load."
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func observePlayer() {
        timeControlObserver?.invalidate()
        timeControlObserver = player?.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] p, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    break
                }
                self.updateNowPlayingInfo()
            }
        }
    }

    nonisolated func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from track: AVPlayerItemTrack?
    ) {
        for group in groups {
            for item in group.items {
                Task {
                    if let stringValue = try? await item.load(.stringValue),
                       !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        await MainActor.run {
                            self.liveMetadataTitle = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.updateNowPlayingInfo()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int?) {
        sleepTimer?.invalidate()
        sleepTimer = nil

        guard let minutes = minutes, minutes > 0 else {
            sleepTimerRemainingSeconds = nil
            return
        }

        sleepTimerRemainingSeconds = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let remaining = self.sleepTimerRemainingSeconds {
                    if remaining <= 1 {
                        self.sleepTimerRemainingSeconds = nil
                        self.sleepTimer?.invalidate()
                        self.sleepTimer = nil
                        self.pause()
                    } else {
                        self.sleepTimerRemainingSeconds = remaining - 1
                    }
                }
            }
        }
    }

    var formattedSleepTimer: String? {
        guard let sec = sleepTimerRemainingSeconds else { return nil }
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Stream Recorder

    var recordingsDirectory: URL {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = musicDir.appendingPathComponent("FreeRadio Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard let station = currentStation, let streamURL = station.streamURL else {
            errorMessage = "Select and play a station first to record."
            return
        }

        let safeName = station.displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let ext = station.displayCodec.lowercased().contains("aac") ? "aac" : "mp3"
        let filename = "\(safeName)_\(timestamp).\(ext)"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)

        do {
            recordingBytes = 0
            recordingDurationSeconds = 0
            let delegate = try StreamRecorderDelegate(fileURL: fileURL) { [weak self] bytes in
                Task { @MainActor in
                    self?.recordingBytes += bytes
                }
            }
            self.recordingDelegate = delegate
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            self.recordingSession = session
            let task = session.dataTask(with: streamURL)
            self.recordingTask = task
            task.resume()
            self.isRecording = true

            recordingTimer?.invalidate()
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.recordingDurationSeconds += 1
                }
            }
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        recordingTask?.cancel()
        recordingTask = nil
        recordingDelegate?.close()
        recordingDelegate = nil
        recordingSession?.invalidateAndCancel()
        recordingSession = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecording = false
        refreshRecordingsList()
    }

    func refreshRecordingsList() {
        let dir = recordingsDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            recordedClips = []
            return
        }

        var clips: [RecordedClip] = []
        for url in files {
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let created = values?.creationDate ?? Date()
            let size = Int64(values?.fileSize ?? 0)
            if size > 0 {
                clips.append(
                    RecordedClip(
                        url: url,
                        stationName: url.deletingPathExtension().lastPathComponent,
                        createdAt: created,
                        fileSize: size
                    )
                )
            }
        }
        recordedClips = clips.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteRecording(_ clip: RecordedClip) {
        try? FileManager.default.removeItem(at: clip.url)
        refreshRecordingsList()
    }

    // MARK: - Animated Visualizer

    private func startVisualizerTimer() {
        visualizerTimer = Timer.scheduledTimer(withTimeInterval: 0.14, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isPlaying && !self.isBuffering && !self.isMuted && self.volume > 0.01 {
                    self.visualizerLevels = (0..<16).map { _ in
                        CGFloat.random(in: 0.18...0.98)
                    }
                } else {
                    self.visualizerLevels = Array(repeating: 0.15, count: 16)
                }
            }
        }
    }

    // MARK: - macOS Media Keys & Now Playing Center

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let station = self.currentStation else { return }
                self.play(station: station)
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        if let station = currentStation {
            nowPlayingInfo[MPMediaItemPropertyTitle] = liveMetadataTitle.isEmpty ? station.displayName : liveMetadataTitle
            nowPlayingInfo[MPMediaItemPropertyArtist] = "\(station.flagEmoji) \(station.displayName) • \(station.displayCountry)"
            nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
