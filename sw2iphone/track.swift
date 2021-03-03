//
//  track.swift
//
//  Based on track.swift from https://github.com/jmkerr/idbcl/
//  Portions copyright (c) 2019 Jonathan Kerr (MIT License)
//  Additions by akda5id, also MIT Licensed
//  SPDX-License-Identifier: MIT

import iTunesLibrary
import Foundation

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
    
    var title: String? {
        return item.value(forProperty: ITLibMediaItemPropertyTitle) as? String
    }
    
    var comments: String? {
        return item.value(forProperty: ITLibMediaItemPropertyComments) as? String
    }
    
    var SwID: Int64? {
        if let com = self.comments {
            if let res = com.components(separatedBy: "SwTrackID:").last {
                return Int64(res)
            }
        }
        return nil
    }
    
    var path: String {
        let url = item.value(forProperty: ITLibMediaItemPropertyLocation) as! URL
        return url.path
    }
    
    var playCount: Int? { return item.value(forProperty: ITLibMediaItemPropertyPlayCount) as? Int}
    var lastPlayed: Int? {
        let date = item.value(forProperty: ITLibMediaItemPropertyLastPlayDate) as? Date
        if date != nil { return Int(date!.timeIntervalSince1970) } else { return nil }
    }
    var lastPlayedDate: Date? {
        let date = item.value(forProperty: ITLibMediaItemPropertyLastPlayDate) as? Date
        if date != nil { return date! } else { return nil }
    }
    
}
