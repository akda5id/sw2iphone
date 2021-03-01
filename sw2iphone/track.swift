//
//  track.swift
//
//
//  Based on track.swift from https://github.com/jmkerr/idbcl/
//  Portions copyright (c) 2019 Jonathan Kerr (MIT License)

import iTunesLibrary

let DEFAULT_RATING: Int = 0
let DEFAULT_PLAY_COUNT: Int = 0

protocol Track: CustomStringConvertible {
    var persistentID: String { get }
    func value(forProperty: String) -> Any?
    var playCount: Int? { get }
    var rating: Int? { get }
}

extension Track {
    func stringValue(forProperty property: String) -> String? {
        if let value = value(forProperty: property) {
            switch value {
            case let string as String:
                return string
            case let int as Int:
                return int.description
            default:
                return String(describing: value)
            }
        } else {
            return nil
        }
    }
    
    public var description: String {
        if let title = stringValue(forProperty: ITLibMediaItemPropertyTitle) {
            return "Title: \(title)"
        }
        return "ID: \(persistentID)"
    }
}



class LibraryTrack: Track {
    let persistentID: String
    let item: ITLibMediaItem
    
    init(fromItem item: ITLibMediaItem) {
        self.item = item
        persistentID = String(format: "%016llX", item.persistentID.uint64Value)
    }

    func value(forProperty property: String) -> Any? {
        return item.value(forProperty: property)
    }
    
    var rating: Int? {
        if item.isRatingComputed { return nil }
        else { return item.value(forProperty: ITLibMediaItemPropertyRating) as? Int }
    }
    
    var playCount: Int? { return item.value(forProperty: ITLibMediaItemPropertyPlayCount) as? Int}
}



public class DatabaseTrack: Track {
    public static let metadataLayout = [
        ITLibMediaItemPropertyAlbumTitle
        , ITLibMediaItemPropertyArtistName
        , ITLibMediaItemPropertyBitRate
        , ITLibMediaItemPropertyComments
        , ITLibMediaItemPropertyFileSize
        , ITLibMediaItemPropertyGenre
        , ITLibMediaItemPropertyKind
        , ITLibMediaItemPropertyPlayCount
        , ITLibMediaItemPropertyRating
        , ITLibMediaItemPropertySampleRate
        , ITLibMediaItemPropertyTitle
        , ITLibMediaItemPropertyTotalTime
        , ITLibMediaItemPropertyYear
    ]
    
    let meta: [Any?]
    let playCounts: [(String, Int, Int)]
    let ratings: [(String, Int, Int)]
    
    var persistentID: String { return meta[0] as! String }
    var playCount: Int? { return playCount() }
    var rating: Int? { return rating() }
    
    init(meta: [Any?], playCounts: [(String, Int, Int)] = [], ratings: [(String, Int, Int)] = []) {
        assert(meta.count == DatabaseTrack.metadataLayout.count + 1, "Wrong usage of DatabaseTrack.init()")
        assert((meta[0] as? String)?.range(of: "^[0-9A-F]{16}$", options: .regularExpression, range: nil, locale: nil) != nil, "Not an ID: \(String(describing: meta[0]))")
        
        self.playCounts = playCounts.sorted(by: { $0.1 > $1.1 })
        self.ratings = ratings.sorted(by: { $0.1 > $1.1 })
        self.meta = meta
    }
    
    func playCount(date: Int = Int(Date().timeIntervalSince1970)) -> Int? {
        let bestPc = playCounts.first(where: { $0.1 < date })
        if let pc = bestPc { return pc.2 } else { return nil }
    }
    
    func rating(date: Int = Int(Date().timeIntervalSince1970)) -> Int? {
        let bestRating = ratings.first(where: { $0.1 < date })
        if let r = bestRating { return r.2 } else { return nil }
    }
    
    func value(forProperty property: String) -> Any? {
        if let index = DatabaseTrack.metadataLayout.firstIndex(of: property) {
            return meta[index + 1]
        } else {
            return nil
        }
    }
}
