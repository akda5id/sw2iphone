//
//  sync.swift
//
//  ITLibrary code from updater.swift from https://github.com/jmkerr/idbcl/
//  Portions copyright (c) 2019 Jonathan Kerr (MIT License)
//  Additions by akda5id, also MIT Licensed
//  SPDX-License-Identifier: MIT

import Foundation
import iTunesLibrary
import GRDB

func doSync() -> Void {
    var lib: ITLibrary?
    do {
        lib = try ITLibrary(apiVersion: "1.1")

        if let applicationVersion: String = lib?.applicationVersion,
            let apiMajorVersion: Int = lib?.apiMajorVersion,
            let apiMinorVersion: Int = lib?.apiMinorVersion
        {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            let msg: String = String(format: "%@: iTunesLibrary version %@, API %d.%d",
                                     df.string(from: Date()), applicationVersion, apiMajorVersion, apiMinorVersion)
            l.info("\(msg)")
        } else {
            l.error("Error connecting to iTunes")
        }
    } catch {
        l.error("Error connecting to iTunes \(error)")
    }
    
    guard let mediaItems = lib?.allMediaItems else {
        l.error("Invalid operation")
        return
    }
    let songItems = mediaItems.filter { $0.mediaKind == ITLibMediaItemMediaKind.kindSong }
    if songItems.count < 1 {
        l.error("The iTunes-Library is empty.")
        checkForStaleITTracks()
        return
    }

    for item in songItems {
        let tr = LibraryTrack(fromItem: item)
        let rating: Int = (tr.rating ?? 0)/20
        let playcount: Int = tr.playCount ?? 0
//        l.trace("doing \(tr.path)")
        
        var our_track_opt: OurTracks?
        OurDB.read { db in
            let request = OurTracks.filter(OurTracks.Columns.our_track_path == tr.path)
            our_track_opt = try? request.fetchOne(db)
        }
        guard let our_track = our_track_opt else {
            l.debug("didn't find id for \(tr.path)")
            continue
        }
        
        if (rating == 0) && (playcount == 0) {
            our_track.our_lastseen_it = run_started
            ourTrackSave(our_track)
            continue
        }
        var rating_to_set: Int?
        var playcount_to_set: Int?
        var lastplayed_to_set: String?
        
        var playcount_to_db: Int64 = our_track.our_playcount!
        
        var sw_track_opt: SwTrack?
        SwDB.read { db in
            let request = SwTrack.filter(key: our_track.our_track_id)
            sw_track_opt = try? request.fetchOne(db)
        }
        
        guard let sw_track = sw_track_opt else {
            l.warning("we didn't find \(tr.path) in Swinsian, though we had an ID for it")
            continue
        }
        
        if rating > 0 {
            if sw_track.sw_rating != rating {
                if sw_track.sw_rating > 0 {
                    l.warning("rating for \(tr.path) differs in Swinsian and iTunes. I'm not sure which to use, skipping")
                } else {
                    rating_to_set = rating
                }
            }
        }

        if Int(our_track.our_playcount!) < playcount {
            playcount_to_set = playcount - Int(our_track.our_playcount!)
            playcount_to_db = Int64(playcount)
        }
        
        let localDateFormatter = DateFormatter()
        localDateFormatter.dateStyle = .medium
        localDateFormatter.timeStyle = .medium
        
        if tr.lastPlayedDate != nil {
            let dateString = localDateFormatter.string(from: tr.lastPlayedDate!)
            let dateStamp = tr.lastPlayedDate!.timeIntervalSinceReferenceDate - 65
            if let sw_lastplayed = sw_track.sw_lastplayed {
                if TimeInterval(dateStamp) > TimeInterval(sw_lastplayed) {
                    l.trace("we have a newer last played \(TimeInterval(dateStamp)) vs \(TimeInterval(sw_lastplayed)) for \(our_track.our_track_path)")
                    lastplayed_to_set = dateString
                }
            } else {
                l.trace("sw doesn't have a played date for \(our_track.our_track_path)")
                lastplayed_to_set = dateString
            }
        }
        
        if (rating_to_set != nil) && (playcount_to_set != nil) && (lastplayed_to_set != nil) {
            doAll(withOurTrack: our_track, withRating: rating_to_set!, withPlaycount: playcount_to_set!, withLastplayed: lastplayed_to_set!)
        } else if (rating_to_set != nil) && (playcount_to_set != nil)  {
            doRatingAndPlaycount(withOurTrack: our_track, withRating: rating_to_set!, withPlaycount: playcount_to_set!)
        } else if (playcount_to_set != nil) && (lastplayed_to_set != nil) {
            doPlaycountAndLastplayed(withOurTrack: our_track, withPlaycount: playcount_to_set!, withLastplayed: lastplayed_to_set!)
        } else if (rating_to_set != nil) && (lastplayed_to_set != nil) {
            doRatingAndLastplayed(withOurTrack: our_track, withRating: rating_to_set!, withLastplayed: lastplayed_to_set!)
        } else if playcount_to_set != nil {
            doPlaycount(withOurTrack: our_track, withPlaycount: playcount_to_set!)
        } else if rating_to_set != nil {
            doRating(withOurTrack: our_track, withRating: rating_to_set!)
        } else if lastplayed_to_set != nil {
            doLastplayed(withOurTrack: our_track, withLastplayed: lastplayed_to_set!)
        } else {
            l.trace("nothing to do on \(tr.path)")
        }
        
        if !dry_run {
            our_track.our_playcount = playcount_to_db
        }
        our_track.our_lastseen_it = run_started
        ourTrackSave(our_track)
    }
    checkForStaleITTracks()
}

func checkForStaleITTracks() -> Void {
    if dry_run {
        do {
            try OurDB.read { db in
                let res = try OurTracks.filter((OurTracks.Columns.our_lastseen_it < run_started) && (OurTracks.Columns.our_lastseen_it != 1.0)).fetchCount(db)
                if res > 0 {
                    l.warning("\(res) were detected removed from iTunes. If this wasn't a dry run, I would have I taken care of reseting my database for those tracks.")
                }
            }
        } catch let error as DatabaseError {
            l.error("got db error \(error.message ?? "")")
            exit(1)
        } catch {
            l.error("got unknown error \(error)")
            exit(1)
        }
        return
    }
    do {
        try OurDB.write { db in
            let res = try OurTracks.filter(
                (OurTracks.Columns.our_lastseen_it < run_started) &&
                (OurTracks.Columns.our_lastseen_it != 1.0))
                    .updateAll(db,
                    OurTracks.Columns.our_lastseen_it.set(to: 1),
                    OurTracks.Columns.our_playcount.set(to: 0))
            if res > 0 {
                if !clean {
                    l.warning("\(res) were detected removed from iTunes. I took care of reseting my database for those tracks. If you would like to remove those files from disk if we created them, run with the --clean flag set")
                } else {
                    l.info("\(res) were detected removed from iTunes.")
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

func ourTrackSave(_ our_track: OurTracks) {
    do {
        try OurDB.write { db in
            try our_track.save(db)
        }
    } catch let error as DatabaseError {
        l.error("got db error \(error.message ?? "")")
        exit(1)
    } catch {
        l.error("got unknown error \(error)")
        exit(1)
    }
}

func doAll(withOurTrack our_track: OurTracks, withRating rating_to_set: Int, withPlaycount playcount_to_set: Int, withLastplayed lastplayed_to_set: String) {
    if dry_run {
        l.debug("would do rating, playcount and lastplayed on \(our_track.our_track_path)")
        return
    }
    l.debug("doing rating, playcount and lastplayed on \(our_track.our_track_path)")
    let source = """
            tell application "Swinsian"
                set thetrack to track id \(our_track.our_track_id)
                set foo to play count of thetrack
                set bar to foo + \(playcount_to_set)
                set play count of thetrack to bar
                set rating of thetrack to \(rating_to_set)
                set last played of thetrack to date "\(lastplayed_to_set)"
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}

func doPlaycountAndLastplayed(withOurTrack our_track: OurTracks, withPlaycount playcount_to_set: Int, withLastplayed lastplayed_to_set: String) {
    if dry_run {
        l.debug("would do playcount and lastplayed on \(our_track.our_track_path)")
        return
    }
    l.debug("doing playcount and lastplayed on \(our_track.our_track_path)")
    let source = """
            tell application "Swinsian"
                set thetrack to track id \(our_track.our_track_id)
                set foo to play count of thetrack
                set bar to foo + \(playcount_to_set)
                set play count of thetrack to bar
                set last played of thetrack to date "\(lastplayed_to_set)"
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}

func doRatingAndLastplayed(withOurTrack our_track: OurTracks, withRating rating_to_set: Int, withLastplayed lastplayed_to_set: String) {
    if dry_run {
        l.debug("would do rating and lastplayed on \(our_track.our_track_path)")
        return
    }
    l.warning("doing rating and lastplayed on \(our_track.our_track_path) not sure how we got here!")
    let source = """
            tell application "Swinsian"
                set thetrack to track id \(our_track.our_track_id)
                set rating of thetrack to \(rating_to_set)
                set last played of thetrack to date "\(lastplayed_to_set)"
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}

func doRatingAndPlaycount(withOurTrack our_track: OurTracks, withRating rating_to_set: Int, withPlaycount playcount_to_set: Int) {
    if dry_run {
        l.debug("would do rating, playcount on \(our_track.our_track_path)")
        return
    }
    l.debug("doing rating and playcount on \(our_track.our_track_path)")
    let source = """
            tell application "Swinsian"
                set thetrack to track id \(our_track.our_track_id)
                set foo to play count of thetrack
                set bar to foo + \(playcount_to_set)
                set play count of thetrack to bar
                set rating of thetrack to \(rating_to_set)
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}

func doPlaycount(withOurTrack our_track: OurTracks, withPlaycount playcount_to_set: Int) {
    if dry_run {
        l.debug("would do playcount on \(our_track.our_track_path)")
        return
    }
    l.debug("doing playcount on \(our_track.our_track_path)")
    let source = """
        tell application "Swinsian"
            set thetrack to track id \(our_track.our_track_id)
            set foo to play count of thetrack
            set bar to foo + \(playcount_to_set)
            set play count of thetrack to bar
        end tell
    """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}

func doRating(withOurTrack our_track: OurTracks, withRating rating_to_set: Int) {
    if dry_run {
        l.debug("would do rating on \(our_track.our_track_path)")
        return
    }
    l.debug("doing rating on \(our_track.our_track_path)")
    let source = """
            tell application "Swinsian"
                set thetrack to track id \(our_track.our_track_id)
                set rating of thetrack to \(rating_to_set)
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}

func doLastplayed(withOurTrack our_track: OurTracks, withLastplayed lastplayed_to_set: String) {
    if dry_run {
        l.debug("would do lastplayed on \(our_track.our_track_path)")
        return
    }
    l.debug("doing lastplayed \(lastplayed_to_set) on \(our_track.our_track_path)")
    let source = """
            tell application "Swinsian"
                set thetrack to track id \(our_track.our_track_id)
                set last played of thetrack to date "\(lastplayed_to_set)"
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        }
    }
}
