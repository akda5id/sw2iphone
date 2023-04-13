//
//  exportPlaylistAplScript.swift
//
//  By akda5id
//  SPDX-License-Identifier: MIT

import Foundation
import GRDB

func saveTrackInfo(_ track: SwTrack) {
    if dry_run { return }
    do {
        try OurDB.write { db in
            if track.we_created_it != nil {
                if track.we_created_it! {
                    let to_sql = OurTracks(our_track_id: Int64(track.id), our_track_path: track.path, our_playcount: 0, our_lastseen_sw: run_started, our_we_created_it: track.we_created_it)
                    try to_sql.save(db)
                } else {
                    l.error("I don't think we should ever be here ZZ2")
                    let to_sql = OurTracks(our_track_id: Int64(track.id), our_track_path: track.path, our_lastseen_sw: run_started, our_we_created_it: track.we_created_it)
                    try to_sql.save(db)
                }
            } else {
                let to_sql = OurTracks(our_track_id: Int64(track.id), our_track_path: track.path, our_lastseen_sw: run_started, our_we_created_it: track.we_created_it)
                try to_sql.save(db)
            }
        }
    } catch let error as DatabaseError {
        if error.message == "no such table: our_tracks" {
            l.trace("creating table our_tracks")
            createOurTracksTable()
            saveTrackInfo(track)
        } else {
            l.error("got db error \(error.message ?? "")")
            exit(1)
        }
    } catch {
        l.error("got unknown error \(error)")
        exit(1)
    }
}

func exportPlaylistAplScript(_ playlist: String) {
    let tracks = getTracks(playlist)
    if tracks.isEmpty {
        l.error("empty playlist")
        return
    }
    var fileHandle: FileHandle?
    if dry_run {
        l.trace("dry run export")
    } else {
        do {
            if playlist_loc == nil {
                l.error("playlist loc is not set")
                exit(1)
            }
            fileHandle = try FileHandle(forWritingTo: playlist_loc!)
            fileHandle?.seekToEndOfFile()
        } catch {
            l.error("Error writing to file \(error)")
        }
    }
    defer { fileHandle?.closeFile() }
    
    for track in tracks {
        if track.kind == "MP3" {
            if !dry_run {
                fileHandle?.write("#EXTINF:\(track.duration),\(track.artist ?? "") - \(track.title ?? "")\n".data(using: .utf8)!)
                let fileURL = URL(fileURLWithPath: track.path)
                fileHandle?.write("\(fileURL.absoluteString)\n".data(using: .utf8)!)
            }
        } else if track.kind == "FLAC" {
            if !createMp3(withTrack: track) {
                l.error("failed to create mp3 for \(track.path)")
                continue
            }
            if !dry_run {
                fileHandle?.write("#EXTINF:\(track.duration),\(track.artist ?? "") - \(track.title ?? "")\n".data(using: .utf8)!)
                let fileURL = URL(fileURLWithPath: track.path)
                fileHandle?.write("\(fileURL.absoluteString)\n".data(using: .utf8)!)
            }
        } else {
            l.warning("track \(track.path) is not recognized")
            continue
        }
        saveTrackInfo(track)
    }
}

func checkForImage(_ track: SwTrack) -> String? {
    let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let tmp_path = temporaryDirectoryURL.appendingPathComponent("\(track.id).jpg").path
    
    let metaflac = Process()
    let pipe = Pipe()

    metaflac.standardOutput = pipe
    metaflac.standardError = pipe
    metaflac.arguments = ["--export-picture-to=\(tmp_path)", track.path]
    metaflac.launchPath = "/usr/local/bin/metaflac"
    metaflac.launch()
    metaflac.waitUntilExit()
    let status = metaflac.terminationStatus
    
    if status == 0 {
        return tmp_path
    }
    //no picture embedded, so let's check for one in the folder
    l.trace("checking for folder image at \(track.path)")
    let folder_url = URL(fileURLWithPath: track.path).deletingLastPathComponent()
    let to_check = ["cover.jpg", "cover.jpeg", "front.jpg", "folder.jpg"]
    for filename in to_check {
        if FileManager.default.fileExists(atPath: folder_url.appendingPathComponent(filename).path) {
            do {
                try FileManager.default.copyItem(at: folder_url.appendingPathComponent(filename), to: URL(fileURLWithPath: tmp_path))
                l.trace("think we coppied \(folder_url.appendingPathComponent(filename))")
                if (FileManager.default.contentsEqual(atPath: folder_url.appendingPathComponent(filename).path, andPath: tmp_path)) {
                    return tmp_path
                } else {
                    l.debug("found image file \(folder_url.appendingPathComponent(filename).path), but the copy failed")
                    try FileManager.default.removeItem(at: URL(fileURLWithPath: tmp_path))
                }
            } catch {
                l.debug("oops error on the copy \(error)")
                l.error("error copying image for \(folder_url.appendingPathComponent(filename).path) to \(tmp_path)")
            }
//            if ((try? FileManager.default.copyItem(at: folder_url.appendingPathComponent(filename), to: URL(fileURLWithPath: tmp_path))) != nil) {
//                l.trace("think we copied \(folder_url.appendingPathComponent(filename))")
//                return tmp_path
//            } else {
//                l.error("error copying image for \(folder_url.appendingPathComponent(filename).path) to \(tmp_path)")
//            }
        }
    }
    
    return nil
}

func createMp3(withTrack track: SwTrack) -> Bool {
    let filename = "\(track.id).mp3"
    let directory = String(Int(track.id / 1000))
    let output_file = mp3_url!.appendingPathComponent(directory).appendingPathComponent(filename).path
    if FileManager.default.fileExists(atPath: output_file) {
        l.debug("track \(track.path) is already converted to mp3")
        track.path = output_file
        return true
    }
    let dir = URL(fileURLWithPath: output_file).deletingLastPathComponent()
    if dry_run {
        if !dry_run_paths.contains(dir.path) {
            if !FileManager.default.fileExists(atPath: dir.path) {
                l.debug("we would create directory at \(dir.path)")
                dry_run_paths.append(dir.path)
            }
        }
    } else {
        do {
            try FileManager.default.createDirectory(at: dir,
            withIntermediateDirectories: true,
            attributes: nil)
        } catch {
            l.error("failed creating directory \(dir.path)")
            return false
        }
    }
    
    let imageloc = checkForImage(track)
    
    let sox = Process()
    let pipe = Pipe()

    sox.standardOutput = pipe
    sox.arguments = ["-G", track.path, "-t", "wav", "-b", "16", "-", "dither"]
    sox.launchPath = "/usr/local/bin/sox"

    let lame = Process()

    lame.standardInput = pipe
    var args = ["-V", "0", "--silent", "--id3v2-only"]
    if let title = track.title {
        args.append(contentsOf: ["--tt", title])
    }
    if let artist = track.artist {
        args.append(contentsOf: ["--ta", artist])
    }
    if let album = track.album {
        args.append(contentsOf: ["--tl", album])
    }
    if let tracknumber = track.tracknumber {
        args.append(contentsOf: ["--tn", tracknumber])
    }
    if let year = track.year {
        args.append(contentsOf: ["--ty", String(year)])
    }
    if let imageloc = imageloc {
        args.append(contentsOf: ["--ti", imageloc])
    }
    if let comment = track.comment {
        args.append(contentsOf: ["--tc", comment])
    }
    args.append(contentsOf: ["-", output_file])
    lame.arguments = args
    l.trace("lame args \(args.joined(separator: " "))")
    lame.launchPath = "/usr/local/bin/lame"
    var status: Int32 = 0
    if !dry_run {
        sox.launch()
        lame.launch()
        
        lame.waitUntilExit()
        status = lame.terminationStatus
        l.info("created an mp3 for \(track.path)")
    } else {
        l.info("would have created an mp3 for \(track.path)")
    }
    
    if status == 0 {
        track.path = output_file
        track.we_created_it = true
        if let imageloc = imageloc {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: imageloc))
        }
        return true
    } else {
        return false
    }
}

func getTracks(_ playlist: String) -> [SwTrack] {
    guard let count = getPlaylistLength(playlist) else {
        return []
    }
    let source = """
            tell application "Swinsian"
                set thepl to playlist named "\(playlist)"
                set selected to tracks of thepl
                set thelist to {}
                set c to count of selected's items
                repeat with i from 1 to c
                    set tr to item i of selected
                    set end of thelist to tr's id
                end repeat
                return thelist
            end tell
        """
    if let script = NSAppleScript(source: source) {
        var res: NSAppleEventDescriptor
        var error: NSDictionary?
        res = script.executeAndReturnError(&error)
        if let err = error {
            l.error("script error \(err)")
        } else {
            var tracks: [SwTrack] = []
            SwDB.read { db in
                for i in 1...count {
                    guard let id_string = res.atIndex(i)?.stringValue else {
                        l.error("problem with index \(i)")
                        continue
                    }
                    let id = Int(id_string)
                    let request = SwTrack.filter(key: id)
                    let track = try? request.fetchOne(db)
                    if track != nil {
                        tracks.append(track!)
                    } else {
                        l.error("we failed to get a track for \(id_string)")
                    }
                }
            }
            return tracks
        }
    }
    return []
}

func getPlaylistLength(_ playlist: String) -> Int? {
    let source = """
        tell application "Swinsian"
            set thepl to playlist named "\(playlist)"
            set selected to tracks of thepl
            if selected is not {} then
                set c to count of selected's items
                return c
            end if
            return 0
        end tell
    """
    if let script = NSAppleScript(source: source) {
        var count: Int
        var error: NSDictionary?
        count = Int(script.executeAndReturnError(&error).int32Value)
        if let err = error {
            l.error("script error \(err)")
        } else {
            if count > 0 {
                return count
            } else {
                return nil
            }
        }
    }
    return nil
}
