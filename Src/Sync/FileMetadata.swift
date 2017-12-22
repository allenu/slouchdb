//
//  FileMetadata.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/22/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct FileMetadata {
    let filename: String
    let lastModifiedDate: Date
    let filesize: Int
    
    public init(filename: String, lastModifiedDate: Date, filesize: Int) {
        self.filename = filename
        self.lastModifiedDate = lastModifiedDate
        self.filesize = filesize
    }
}

extension FileMetadata {
    public static func from(dictionary: [String : Any]) -> FileMetadata? {
        if let filesize = dictionary["filesize"] as? Int,
            let filename = dictionary["filename"] as? String,
            let lastModifiedDateString = dictionary["lastModified"] as? String {
            if let lastModifiedDate = DateFromString(lastModifiedDateString) {
                return FileMetadata(filename: filename, lastModifiedDate: lastModifiedDate, filesize: filesize)
            }
        }
        return nil
    }
    
    public static func lookupDictionaryFrom(dictionary: [String : Any]) -> [String : FileMetadata]? {
        if let files = dictionary["files"] as? [String : Any] {
            var syncMetadata: [String : FileMetadata] = [:]
            for keyValue in files {
                let filename = keyValue.key
                if let fileMetadataDictionary = keyValue.value as? [String : Any] {
                    if let fileMetadata = FileMetadata.from(dictionary: fileMetadataDictionary) {
                        syncMetadata[filename] = fileMetadata
                    }
                }
            }
            return syncMetadata
        } else {
            return nil
        }
    }
    
    static func toDictionaryFromLookup(lookup: [String : FileMetadata]) -> [String : Any] {
        var syncMetadataDictionary: [String : Any] = [:]
        
        for keyValue in lookup {
            let filename = keyValue.key
            let metadata = keyValue.value
            syncMetadataDictionary[filename] = metadata.toDictionary()
        }
        
        let topDictionary = ["files" : syncMetadataDictionary]
        return topDictionary
    }
    
    func toDictionary() -> [String : Any] {
        let metadataDictionary: [String : Any] = ["filename": filename,
                                                  "filesize": filesize,
                                                  "lastModified": StringFromDate(lastModifiedDate)]
        return metadataDictionary
    }
}
