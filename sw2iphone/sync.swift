//
//  sync.swift
//
//
//  Based on updater.swift from https://github.com/jmkerr/idbcl/
//  Portions copyright (c) 2019 Jonathan Kerr (MIT License)



import iTunesLibrary

public class MediaLibrary {
    private let lib: ITLibrary?
    private let dbUrl: URL
    
    public init?(dbUrl: URL) {
        do {
            lib = try ITLibrary(apiVersion: "1.1")
        } catch {
            print("Error initializing ITLibrary: \(error)")
            return nil
        }
        
        if let applicationVersion: String = lib?.applicationVersion,
            let apiMajorVersion: Int = lib?.apiMajorVersion,
            let apiMinorVersion: Int = lib?.apiMinorVersion
        {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            let msg: String = String(format: "%@: iTunesLibrary version %@, API %d.%d",
                                     df.string(from: Date()), applicationVersion, apiMajorVersion, apiMinorVersion)
            print(msg)
        }
        
        let dbDirectory: URL = dbUrl.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dbDirectory,
                                                        withIntermediateDirectories: false,
                                                        attributes: nil)
            print("Creating " + dbDirectory.path)
        } catch CocoaError.fileWriteFileExists {
            // Ignore error
        } catch {
            print("Error creating directory \(dbDirectory): \(error)")
            return nil
        }
            
        self.dbUrl = dbUrl
    }

    public func updateDB(dryRun: Bool) {
        if let mediaItems = lib?.allMediaItems,
            let db = Updater(dbFileURL: self.dbUrl, dryRun: dryRun) {
            let songItems = mediaItems.filter { $0.mediaKind == ITLibMediaItemMediaKind.kindSong }
            if songItems.count > 0 {
                for item in songItems {
                    let tr = LibraryTrack(fromItem: item)
                    db.updateMeta(forTrack: tr)
                    db.updatePlayCounts(forTrack: tr)
                    db.updateRatings(forTrack: tr)
                }
            } else {
                print("The iTunes-Library is empty.")
            }
        } else {
            print("Invalid operation")
        }
    }
}
