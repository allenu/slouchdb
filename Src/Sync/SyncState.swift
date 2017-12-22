//
//  SyncState.swift
//  SlouchNotesPocket
//
//  Created by Allen Ussher on 12/21/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct SyncState {
    public var journalFileMetadata: [String : JournalFileMetadata]
    public var localMetadata: [String : FileMetadata]
    public var remoteMetadata: [String : FileMetadata]
    
    public init(journalFileMetadata: [String : JournalFileMetadata] = [:],
                localMetadata: [String : FileMetadata] = [:],
                remoteMetadata: [String : FileMetadata] = [:]) {
        self.journalFileMetadata = journalFileMetadata
        self.localMetadata = localMetadata
        self.remoteMetadata = remoteMetadata
    }
}

extension SyncState {
    public func toDictionary() -> [String : Any] {
        var result: [String : Any] = [:]
        
        var localJournalMetadataDictionary: [String : Any] = [:]
        for keyValue in journalFileMetadata {
            localJournalMetadataDictionary[keyValue.key] = keyValue.value.toDictionary()
        }
        
        result["localJournalMetadata"] = localJournalMetadataDictionary
        result["local"] = FileMetadata.toDictionaryFromLookup(lookup: localMetadata)
        result["remote"] = FileMetadata.toDictionaryFromLookup(lookup: remoteMetadata)
        
        return result
    }
    
    public static func from(dictionary: [String : Any]) -> SyncState? {
        if let localJournalMetadataDictionary = dictionary["localJournalMetadata"] as? [String : Any],
            let localMetadataDictionary = dictionary["local"] as? [String : Any],
            let remoteMetadataDictionary = dictionary["remote"] as? [String : Any] {
            
            var journalFileMetadata: [String : JournalFileMetadata] = [:]
            for keyValue in localJournalMetadataDictionary {
                if let dictionary = keyValue.value as? [String : Any] {
                    journalFileMetadata[keyValue.key] = JournalFileMetadata.from(dictionary: dictionary)
                }
            }
            if let localMetadata = FileMetadata.lookupDictionaryFrom(dictionary: localMetadataDictionary),
                let remoteMetadata = FileMetadata.lookupDictionaryFrom(dictionary: remoteMetadataDictionary) {
                return SyncState(journalFileMetadata: journalFileMetadata,
                                 localMetadata: localMetadata,
                                 remoteMetadata: remoteMetadata)
            }
        }
            
        return nil
    }
}
