//
//  FileMetadata.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/22/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation
import SlouchDB // for Date conversion utils

struct FileMetadata {
    let filename: String
    let lastModifiedDate: Date
    let filesize: Int
}

func DeserializeSyncMetadata(fromJsonDictionary jsonDictionary: [String : Any]) -> [String : FileMetadata] {
    var syncMetadata: [String : FileMetadata] = [:]
    
    if let files = jsonDictionary["files"] as? [String : Any] {
        for keyValue in files {
            let filename = keyValue.key
            if let fileMetadataDictionary = keyValue.value as? [String : Any] {
                if let filesize = fileMetadataDictionary["filesize"] as? Int,
                    let lastModifiedDateString = fileMetadataDictionary["lastModified"] as? String {
                    if let lastModifiedDate = DateFromString(lastModifiedDateString) {
                        
                        let fileMetadata = FileMetadata(filename: filename, lastModifiedDate: lastModifiedDate, filesize: filesize)
                        syncMetadata[filename] = fileMetadata
                    }
                }
            }
        }
    }
    
    return syncMetadata
}

func SerializeSyncMetadata(syncMetadata: [String : FileMetadata]) -> Data {
    var syncMetadataDictionary: [String : Any] = [:]
    
    for keyValue in syncMetadata {
        let filename = keyValue.key
        let metadata = keyValue.value
        let metadataDictionary: [String : Any] = ["filename": filename,
                                                  "filesize": metadata.filesize,
                                                  "lastModified": StringFromDate(metadata.lastModifiedDate)]
        
        syncMetadataDictionary[filename] = metadataDictionary
    }
    
    let topDictionary = ["files" : syncMetadataDictionary]
    
    let data = try! JSONSerialization.data(withJSONObject: topDictionary, options: [])
    return data
}
