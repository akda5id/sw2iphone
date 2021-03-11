//
//  clean.swift
//
//  By akda5id
//  SPDX-License-Identifier: MIT


import Foundation
import GRDB

func cleanTracks() -> Void {
    do {
        try OurDB.write { db in
            let needscleaned = OurTracks.select(OurTracks.Columns.our_track_id, OurTracks.Columns.our_track_path).filter((OurTracks.Columns.our_lastseen_it == 1.0) && (OurTracks.Columns.our_we_created_it == 1))
            let count = try needscleaned.fetchCount(db)
            if count == 0 {
                l.info("No tracks need to be cleaned from disk")
                return
            } else {
                for track in try needscleaned.fetchAll(db) {
                    let path = track.our_track_path
                    let id = track.our_track_id
                    if dry_run {
                        l.info("would delete \(path)")
                        continue
                    }
                    l.debug("deleting \(path)")
                    if ((try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))) == nil) {
                        l.warning("failed to delete \(path)")
                    } else {
                        try OurTracks.deleteOne(db, key: id)
                    }
                }
            }
        }
    } catch let error as DatabaseError {
        l.error("got db error \(error.message ?? "")")
        exit(1)
    } catch {
        l.error("got unknown error \(error)")
        exit(1)
    }
}

func checkForStaleSWTracks(_ age: Int) {
    let threshold = run_started - Double(age * 60)
    l.trace("threshold for stale swinsian tracks is \(threshold)")
    do {
        try OurDB.write { db in
            let stale = OurTracks.select(OurTracks.Columns.our_track_id, OurTracks.Columns.our_track_path).filter((OurTracks.Columns.our_lastseen_sw < threshold) && (OurTracks.Columns.our_lastseen_it > 1.0))
            let count = try stale.fetchCount(db)
            if count == 0 {
                l.info("No tracks older than \(age) minutes found")
                return
            } else {
                guard let mp3_url = mp3_url else {
                    l.error("problem with mp3 url")
                    exit(1)
                }
                let playlist_loc = mp3_url.appendingPathComponent("to_Delete.m3u8")
                try "#EXTM3U\n".write(to: playlist_loc, atomically: true, encoding: String.Encoding.utf8)
                var fileHandle: FileHandle = try FileHandle(forWritingTo: playlist_loc)
                fileHandle.seekToEndOfFile()
                defer { fileHandle.closeFile() }
                
                for track in try stale.fetchAll(db) {
                    let path = track.our_track_path
                    let id = track.our_track_id
                    if dry_run {
                        l.info("would mark \(id) \(path) as stale")
                        continue
                    }
                    l.debug("marking \(id) \(path) stale")
                    track.our_lastseen_sw = 1.0
                    try track.update(db)
                    //write playlist
                    fileHandle.write("#EXTINF: ,  - \n".data(using: .utf8)!)
                    fileHandle.write("\(path)\n".data(using: .utf8)!)
                }
                l.warning("\(count) tracks were added to \(playlist_loc). You should load that into iTunes, and then delete all tracks in the playlist from library, and then run --sync")
            }
        }
    } catch let error as DatabaseError {
        l.error("got db error \(error.message ?? "")")
        exit(1)
    } catch {
        l.error("got unknown error \(error)")
        exit(1)
    }
    exit(1)
}

