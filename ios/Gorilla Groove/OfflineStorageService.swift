import Foundation

class OfflineStorageService {
    
    @SettingsBundleStorage(key: "offline_storage_used")
    private static var offlineStorageUsed: String
    
    @SettingsBundleStorage(key: "offline_storage_fetch_mode")
    private static var offlineStorageFetchMode: OfflineStorageFetchModeType
    
    @SettingsBundleStorage(key: "max_offline_storage")
    private static var maxOfflineStorage: Int
    
    @SettingsBundleStorage(key: "offline_storage_enabled")
    private static var offlineStorageEnabled: Bool
    
    @SettingsBundleStorage(key: "always_offline_cached")
    private static var alwaysOfflineSongsCached: String
    
    @SettingsBundleStorage(key: "tracks_temporarily_cached")
    private static var tracksTemporarilyCached: String
    
    private static var currentBytesStored = 0
    private static var maxOfflineStorageBytes: Int {
        get {
            // maxOfflineStorage is stored in MB. Need to convert to bytes to do a comparison.
            maxOfflineStorage * 1_000_000
        }
    }
    
    static func initialize() {
        // We read this a lot, so just keep it in memory
        currentBytesStored = FileState.read(DataStored.self)?.stored ?? 0
    }
    
    static func recalculateUsedOfflineStorage() {
        // This makes several DB calls, and several writes to user prefs. It should never be invoked on the main thread.
        if Thread.isMainThread {
            fatalError("Do not call recalculate offline storage on the main thread!")
        }
        
        let nextBytesStored = TrackDao.getTotalBytesStored()
        let nextDataString = formatBytesString(nextBytesStored)
        
        GGLog.debug("Stored bytes went from \(formatBytesString(currentBytesStored)) to \(nextDataString)")
        
        FileState.save(DataStored(stored: nextBytesStored))
        offlineStorageUsed = nextDataString
        
        let totalAvailabilityCounts = TrackDao.getOfflineAvailabilityCounts(cachedOnly: false)
        let usedAvailabilityCounts = TrackDao.getOfflineAvailabilityCounts(cachedOnly: true)
        
        alwaysOfflineSongsCached = "\(usedAvailabilityCounts[OfflineAvailabilityType.AVAILABLE_OFFLINE]!) / \(totalAvailabilityCounts[OfflineAvailabilityType.AVAILABLE_OFFLINE]!)"
        tracksTemporarilyCached = "\(usedAvailabilityCounts[OfflineAvailabilityType.NORMAL]!) / \(totalAvailabilityCounts[OfflineAvailabilityType.NORMAL]!)"
    }
    
    private static func formatBytesString(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    static func shouldTrackBeCached(track: Track) -> Bool {
        if track.offlineAvailability == .ONLINE_ONLY || !offlineStorageEnabled {
            return false
        }
        return currentBytesStored + track.cacheSize < maxOfflineStorageBytes
    }

    
    static func purgeExtraTrackDataIfNeeded(offlineAvailability: OfflineAvailabilityType = .NORMAL) {
        if currentBytesStored < maxOfflineStorage {
            GGLog.info("Current stored bytes of \(currentBytesStored) are within the limit of \(maxOfflineStorageBytes). Not purging track cache")
            return
        }
        
        let bytesToPurge = currentBytesStored - maxOfflineStorageBytes
        
        GGLog.info("New cache limit of \(maxOfflineStorageBytes) is too small for current cache of \(currentBytesStored). Beginning cache purge of \(bytesToPurge) bytes")
        
        let ownId = FileState.read(LoginState.self)!.id

        // Ordered by the last time they were played, with the first one being the track played the LEAST recently.
        let tracksToMaybePurge = TrackDao.getTracks(
            userId: ownId,
            offlineAvailability: offlineAvailability,
            isCached: true,
            sorts: [("last_played", true, false)],
            // We recursively call this function until we've deleted enough.
            // Grab only 100 to keep memory usage down as this is basically a background task, and there's a good chance 100 is enough
            limit: 100
        )
        
        if tracksToMaybePurge.isEmpty {
            if offlineAvailability == .NORMAL {
                GGLog.info("Need to clear always offline song data in order to bring cache down!")
                return purgeExtraTrackDataIfNeeded(offlineAvailability: .AVAILABLE_OFFLINE)
            } else {
                GGLog.critical("Programmer error! Need to clear bytes, but no tracks are available to delete to clear up space?")
                return
            }
        }

        var bytePurgeCount = 0;
        var tracksToPurge: Array<Track> = [];
        
        for track in tracksToMaybePurge {
            if bytePurgeCount > bytesToPurge {
                break
            }
            
            bytePurgeCount += track.cacheSize
            tracksToPurge.append(track)
        }
        
        GGLog.info("Purging \(tracksToPurge.count) tracks from cache")
        
        // There is a lot of potential here to bulk update these in the database. Lot of unnecessary calls here. But this is
        // currently always invoked in the background, and is not very time-sensitive or even likely to happen, as it requires the
        // user to reduce the size of storage allocated to GG which is quite rare. So I am being lazy and punting for now.
        tracksToPurge.forEach { track in
            CacheService.deleteCachedData(trackId: track.id, cacheType: .song)
            CacheService.deleteCachedData(trackId: track.id, cacheType: .art)
        }
        
        if bytePurgeCount < bytesToPurge {
            GGLog.info("Did not clear enough bytes to push cache below the limit (cleared: \(bytePurgeCount) needed: \(bytesToPurge)). Doing another pass")
            purgeExtraTrackDataIfNeeded(offlineAvailability: offlineAvailability)
        }
    }

    struct DataStored: Codable {
        let stored: Int
    }
}


class CacheService {
    private static func baseDir() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func filenameFromCacheType(_ trackId: Int, cacheType: CacheType) -> String {
        switch (cacheType) {
        case .art:
            return "\(trackId).png"
        case .song:
            return "\(trackId).mp3"
        case .thumbnail:
            return "\(trackId)-small.png"
        }
    }
    
    static func setCachedData(trackId: Int, data: Data, cacheType: CacheType) {
        let path = baseDir().appendingPathComponent(filenameFromCacheType(trackId, cacheType: cacheType))
        
        try! data.write(to: path)
        
        TrackDao.setCachedAt(trackId: trackId, cachedAt: Date(), cacheType: cacheType)
        
        // The user-facing logic for considering a song cached state is determined by song data.
        // Firstly, because song data is much bigger and therefore more important, and secondly, because not all tracks have art.
        if cacheType == .song {
            OfflineStorageService.recalculateUsedOfflineStorage()
        }
    }
    
    static func getCachedData(trackId: Int, cacheType: CacheType) -> Data? {
        let path = baseDir().appendingPathComponent(filenameFromCacheType(trackId, cacheType: cacheType))
        
        return try? Data(contentsOf: path)
    }
    
    static func deleteCachedData(trackId: Int, cacheType: CacheType, ignoreWarning: Bool = false) {
        let path = baseDir().appendingPathComponent(filenameFromCacheType(trackId, cacheType: cacheType))
        TrackDao.setCachedAt(trackId: trackId, cachedAt: nil, cacheType: cacheType)

        if FileManager.exists(path) {
            GGLog.info("Deleting cached \(cacheType) for track ID: \(trackId)")
            try! FileManager.default.removeItem(at: path)
        } else if !ignoreWarning {
            GGLog.warning("Attempted to deleting cached \(cacheType) for track ID: \(trackId) at path '\(path)' but it was not found")
        }
        
        if cacheType == .song {
            OfflineStorageService.recalculateUsedOfflineStorage()
        }
    }
    
    static func deleteAllData(trackId: Int) {
        CacheType.allCases.forEach { type in
            deleteCachedData(trackId: trackId, cacheType: type, ignoreWarning: true)
        }
    }
}

extension FileManager {
    static func exists(_ path: URL) -> Bool {
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    static func move(_ oldPath: URL, _ newPath: URL) {
        try! FileManager.default.moveItem(atPath: oldPath.path, toPath: newPath.path)
    }
}


enum OfflineStorageFetchModeType: Int {
    case always = 2
    case wifi = 1
    case never = 0
}

enum CacheType: CaseIterable {
    case song
    case art
    case thumbnail
}
