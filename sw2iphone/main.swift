//
//  main.swift
//
//  By akda5id
//  SPDX-License-Identifier: MIT

import Foundation
import ArgumentParser
import GRDB
import Logging
LoggingSystem.bootstrap(MyStreamLogHandler.standardOutput)
var l = Logger(label: "org.da5id.sw2iphone")
l.logLevel = .warning


let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let SwDB_URL = appSupportURL.appendingPathComponent("Swinsian/Library.sqlite")
let OurDB_URL = appSupportURL.appendingPathComponent("org.da5id.sw2iphone/database.sqlite")

let run_started = Double(Date().timeIntervalSinceReferenceDate)
var mp3_url: URL?
var playlist_loc: URL?
var dry_run: Bool = false
var dry_run_paths: [String] = []
var clean: Bool = false

if !FileManager.default.fileExists(atPath: OurDB_URL.deletingLastPathComponent().path) {
    do {
        try FileManager.default.createDirectory(at: OurDB_URL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
    } catch {
        l.error("failed creating support directory \(OurDB_URL.deletingLastPathComponent().path) \(error)")
        exit(1)
    }
}

var config = Configuration()
//config.prepareDatabase { db in
//    db.trace { print($0) }
//}

var sw_config = Configuration()
sw_config.readonly = true

let SwDB = try DatabaseQueue(path: SwDB_URL.path, configuration: sw_config)
let OurDB = try DatabaseQueue(path: OurDB_URL.path, configuration: config)



func listPlaylists() -> Dictionary<Int, String> {
    let playlists = try? SwDB.read { db in
        try PlaylistTable.fetchAll(db)
    }
    
    if playlists == nil {
        l.error("problem accessing Swinsian database to read playlists")
        exit(1)
    }
    
    var playlists_dict: [Int: String] = [:]
    
    for pl in playlists! {
        print("id: \(pl.s_playlist_id), name: \(pl.s_playlist_name ?? "")")
        playlists_dict[Int(pl.s_playlist_id)] = pl.s_playlist_name ?? ""
    }

    return playlists_dict
}


struct sw2iphone: ParsableCommand {
    @Flag(name: .shortAndLong, help: "Export a playlist to iTunes")
    var export = false
    
    @Flag(name: .shortAndLong, help: "Sync playcounts and ratings back to Swinsian")
    var sync = false
    
    @Flag(name: [.short, .customLong("clean")], help: "Clean up mp3 files we created, if they are no longer in iTunes")
    var cleanflag = false
    
    @Flag(name: [.customLong("v")], help: "Print some messages about what is happening")
    var verbose = false
    
    @Flag(name: [.customLong("vv")], help: "Print even more about what is happening")
    var v_verbose = false
    
    @Flag(name: [.short, .customLong("dry-run")], help: "Don't actually make any changes")
    var dryrunflag = false
    
    @Flag(name: [.customLong("vvv")], help: .hidden)
    var vv_verbose = false
    
    @Option(name: .shortAndLong, help: "Set the path to export to (will be saved for future runs)")
    var path: String?
    
    @Option(name: .shortAndLong, help: "Prepare tracks which haven't been seen in the last x minutes from Swinsian for deletion")
    var age: Int?
    

    func run() {
        if vv_verbose {
            l.logLevel = .trace
        } else if v_verbose {
            l.logLevel = .debug
        } else if verbose {
            l.logLevel = .info
        }
        
        if dryrunflag {
            dry_run = true
            l.trace("dry run starting at \(run_started)")
        } else {
            l.trace("run starting at \(run_started)")
        }
        
        if cleanflag {
            clean = true
        }
        
        if let path = path {
            mp3_url = URL(fileURLWithPath: path)
            saveMp3Path(mp3_path: path)
            l.warning("If there are mp3 files in the old path location, you should either move them over manually or start fresh in iTunes")
        } else {
            let mp3_path = getMp3Path()
            mp3_url = URL(fileURLWithPath: mp3_path)
        }
        guard mp3_url != nil else {
            l.error("error with mp3 path")
            return
        }
        
        var playlist_dict: [Int: String]
        if export {
            playlist_dict = listPlaylists()
            print("enter id number for playlist to export")
            let result = Int(readLine() ?? "") ?? 0
            guard let playlist = playlist_dict[result] else {
                l.error("invalid playlist \(result)")
                return
            }
            print("ok, doing \(playlist)")
            playlist_loc = mp3_url!.appendingPathComponent("\(playlist).m3u8")
            if !dry_run {
                do {
                    try "#EXTM3U\n".write(to: playlist_loc!, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    l.error("Error writing playlist \(error)")
                    return
                }
                l.trace("wrote playlist to \(playlist_loc!.path)")
            } else {
                l.trace("would have wrote playlist to \(playlist_loc!.path)")
            }
            exportPlaylistAplScript(playlist)
            if clean {
                cleanTracks()
            }
            if age != nil {
                checkForStaleSWTracks(age!)
            }
        } else if sync {
            print("Have you quit Swinsian since any playcount or ratings may have happened in the app (including by previous syncs from here)?")
            print("(y)es (or enter), (n)o, (d)o it for me")
            if let result = readLine() {
                if (result.lowercased() == "n") || (result.lowercased() == "no") {
                    print("you should do that first")
                    return
                } else if (result.lowercased() == "d") || (result.lowercased() == "do") || (result.lowercased() == "do it for me") {
                    quitSw()
                } else if (result.lowercased() == "y") || (result.lowercased() == "yes") || (result == "") {
                    print("ok")
                } else {
                    print("I didn't understand the response")
                    return
                }
            }
            doSync()
            if clean {
                cleanTracks()
            }
            if age != nil {
                checkForStaleSWTracks(age!)
            }
        } else if clean {
            cleanTracks()
            if age != nil {
                checkForStaleSWTracks(age!)
            }
        } else if age != nil {
            checkForStaleSWTracks(age!)
        } else {
            let help = sw2iphone.helpMessage()
            print(help)
        }
    }
}

sw2iphone.main()



func quitSw() -> Void {
    l.debug("quittiing Swinsian")
    let source = """
            tell application "Swinsian"
                quit
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

func getMp3Path() -> String {
    var our_path: String?
    OurDB.read { db in
        let request = KeyValue.filter(KeyValue.Columns.key == "mp3_path")
        our_path = try? request.fetchOne(db)?.value
    }
    
    if our_path != nil {
        return our_path!
    } else {
        mp3_url =  FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/sw2iphone/")
        let mp3_path = mp3_url!.path
        saveMp3Path(mp3_path: mp3_path)
        return mp3_path
    }
}

func saveMp3Path(mp3_path: String) {
    if !dry_run {
        do {
            try OurDB.write { db in
                let to_sql = KeyValue(key: "mp3_path", value:mp3_path)
                try to_sql.save(db)
            }
            if !FileManager.default.fileExists(atPath: mp3_url!.path) {
                do {
                    try FileManager.default.createDirectory(at: mp3_url!, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    l.error("failed creating directory \(mp3_url!.path) \(error)")
                    return
                }
            }
        } catch let error as DatabaseError {
            if error.message == "no such table: key_value" {
                l.trace("creating table key_value")
                createKeyValueTable()
                saveMp3Path(mp3_path: mp3_path)
            } else {
                l.error("got db error \(error.message ?? "")")
                exit(1)
            }
        } catch {
            l.error("got unknown error \(error)")
            exit(1)
        }
    } else {
        l.warning("we did not save the new path location \(mp3_path) as we are in a dry run. Make sure you give it again on the real run!")
    }
}
