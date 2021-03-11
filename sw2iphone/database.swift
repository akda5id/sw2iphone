//
//  database.swift
//
//  By akda5id
//  SPDX-License-Identifier: MIT


import Foundation
import GRDB

func createOurTracksTable() {
    do{
        try OurDB.write { db in
            try db.create(table: "our_tracks") { t in
                t.column("our_track_id", .integer).primaryKey()
                t.column("our_track_path", .text).notNull().indexed()
                t.column("our_playcount", .integer).notNull().defaults(to: 0)
                t.column("our_lastseen_it", .double)
                t.column("our_lastseen_sw", .double)
                t.column("our_we_created_it", .boolean).notNull().defaults(to: false)
            }
        }
    } catch {
        l.error("error creating tracks table \(error)")
        exit(1)
    }
}

func createKeyValueTable() {
    do{
        try OurDB.write { db in
            try db.create(table: "key_value") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }
    } catch {
        l.error("error creating key_value table \(error)")
        exit(1)
    }
}

class KeyValue: Record {
    var key: String
    var value: String
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
        super.init()
    }
    
    override class var databaseTableName: String { "key_value" }
    
    enum Columns: String, ColumnExpression {
        case key, value
    }
    
    required init(row: Row) {
        key = row[Columns.key]
        value = row[Columns.value]
        super.init()
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container[Columns.key] = key
        container[Columns.value] = value
    }
}

class OurTracks: Record {
    var our_track_id: Int64
    var our_track_path: String
    var our_playcount: Int64?
    var our_lastseen_it: Double?
    var our_lastseen_sw: Double?
    var our_we_created_it: Bool?
    
    init(our_track_id: Int64, our_track_path: String, our_playcount: Int64? = nil, our_lastseen_it: Double? = nil, our_lastseen_sw: Double? = nil, our_we_created_it: Bool? = nil) {
        self.our_track_id = our_track_id
        self.our_track_path = our_track_path
        self.our_playcount = our_playcount
        self.our_lastseen_it = our_lastseen_it
        self.our_lastseen_sw = our_lastseen_sw
        self.our_we_created_it = our_we_created_it
        super.init()
    }
    
    override class var databaseTableName: String { "our_tracks" }
    
    enum Columns: String, ColumnExpression {
        case our_track_id, our_track_path, our_playcount, our_lastseen_it, our_lastseen_sw, our_we_created_it
    }
    
    required init(row: Row) {
        our_track_id = row[Columns.our_track_id]
        our_track_path = row[Columns.our_track_path]
        our_playcount = row[Columns.our_playcount]
        our_lastseen_it = row[Columns.our_lastseen_it]
        our_lastseen_sw = row[Columns.our_lastseen_sw]
        our_we_created_it = row[Columns.our_we_created_it]
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container[Columns.our_track_id] = our_track_id
        container[Columns.our_track_path] = our_track_path
        if our_playcount != nil {
            container[Columns.our_playcount] = our_playcount
        }
        if our_lastseen_it != nil {
            container[Columns.our_lastseen_it] = our_lastseen_it
        }
        if our_lastseen_sw != nil {
            container[Columns.our_lastseen_sw] = our_lastseen_sw
        }
        if our_we_created_it != nil {
            container[Columns.our_we_created_it] = our_we_created_it
        }
    }
    
}

class PlaylistTable: Record {
    var s_playlist_id: Int64
    var s_playlist_name: String?
    
    init(s_playlist_id: Int64, s_playlist_name: String?) {
        self.s_playlist_id = s_playlist_id
        self.s_playlist_name = s_playlist_name
        super.init()
    }
    
    override class var databaseTableName: String { "playlist" }
    
    enum Columns: String, ColumnExpression {
        case playlist_id, name
    }
    
    required init(row: Row) {
        s_playlist_id = row[Columns.playlist_id]
        s_playlist_name = row[Columns.name]
        super.init(row: row)
    }
}

class SwTrack: Record {
    var sw_track_id: Int64
    var sw_lastplayed: Double?
    var sw_playcount: Int64
    var sw_rating: Int64
    let artist: String?
    let title: String?
    let album: String?
    let year: Int32?
    let tracknumber_pre: Int32?
    let totaltracks: Int32?
    let comment: String?
    let duration: Int32
    var path: String
    var we_created_it: Bool?
    
    init(sw_track_id: Int64, sw_lastplayed: Double?, sw_playcount: Int64, sw_rating: Int64, artist: String?, title: String?, album: String?, year: Int32?, tracknumber_pre: Int32?, totaltracks: Int32?, comment: String?, duration: Int32, path: String, we_created_it: Bool? = nil) {
        self.sw_track_id = sw_track_id
        self.sw_lastplayed = sw_lastplayed
        self.sw_playcount = sw_playcount
        self.sw_rating = sw_rating
        self.artist = artist
        self.title = title
        self.album = album
        self.year = year
        self.tracknumber_pre = tracknumber_pre
        self.totaltracks = totaltracks
        self.comment = comment
        self.duration = duration
        self.path = path
        self.we_created_it = we_created_it
        super.init()
    }
    
    override class var databaseTableName: String { "track" }
    
    enum Columns: String, ColumnExpression {
        case track_id, lastplayed, playcount, rating, artist, title, album, year, tracknumber, totaltracknumber, comment, length, path
    }
    
    required init(row: Row) {
        sw_track_id = row[Columns.track_id]
        sw_lastplayed = row[Columns.lastplayed]
        sw_playcount = row[Columns.playcount]
        sw_rating = row[Columns.rating]
        artist = row[Columns.artist]
        title = row[Columns.title]
        album = row[Columns.album]
        year = row[Columns.year]
        tracknumber_pre = row[Columns.tracknumber]
        totaltracks = row[Columns.totaltracknumber]
        comment = row[Columns.comment]
        duration = row[Columns.length]
        path = row[Columns.path]
        we_created_it = nil
        super.init(row: row)
    }
    
    var kind: String {
        let ext = URL(fileURLWithPath: self.path).pathExtension.lowercased()
        if ext == "mp3" {
            return "MP3"
        } else if ext == "flac" {
            return "FLAC"
        } else {
            return "OTHER"
        }
    }
    
    var id: Int {
        return Int(self.sw_track_id)
    }
    
    var tracknumber: String? {
        guard let tracknumber_pre = tracknumber_pre else {
            return nil
        }
        var output = ""
        if let totaltracks = totaltracks {
            if totaltracks != 0 {
                output = "\(String(tracknumber_pre))/\(String(totaltracks))"
            } else {
                output = (String(tracknumber_pre))
            }
        } else {
            output = (String(tracknumber_pre))
        }
        return output
    }
}

