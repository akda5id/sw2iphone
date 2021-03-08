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
