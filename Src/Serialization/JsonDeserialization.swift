//
//  JsonDeserialization.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public func DeserializeDatabaseState(fromJsonDictionary jsonDictionary: [String : Any]) -> DatabaseObjectState? {
    guard let snapshotDictionary = jsonDictionary["snapshot"] as? [String : Any] else { return nil }
    guard let historyDictionary = jsonDictionary["histories"] as? [String : Any] else { return nil }

    guard let snapshot = DeserializeDatabaseSnapshot(fromJsonDictionary: snapshotDictionary) else { return nil }
    guard let objectHistories = DeserializeJournalSet(fromJsonDictionary: historyDictionary, diffsUseJournalIdentifier: true)
        else { return nil }
    
    return DatabaseObjectState(snapshot: snapshot, objectHistories: objectHistories)
}

public func DeserializeDatabaseSnapshot(fromJsonDictionary jsonDictionary: [String : Any]) -> DatabaseObjectSnapshot? {
    var objects: [String : DatabaseObject] = [:]
    
    for keyValue in jsonDictionary {
        let identifier = keyValue.key
        if let properties = keyValue.value as? DatabaseObjectPropertiesDictionary {
            var creationDate: Date? = nil
            if let creationDateString = properties[DatabaseObject.kCreationDatePropertyKey] {
                creationDate = DateFromString(creationDateString)
            }
            assert(creationDate != nil)
            if creationDate == nil {
                creationDate = Date()
            }
            
            var lastModifiedDate: Date? = nil
            if let lastModifiedDateString = properties[DatabaseObject.kLastModifiedDatePropertyKey] {
                lastModifiedDate = DateFromString(lastModifiedDateString)
            }
            assert(lastModifiedDate != nil)
            if lastModifiedDate == nil {
                lastModifiedDate = creationDate
            }
            
            objects[identifier] = DatabaseObject(identifier: identifier,
                                                 creationDate: creationDate!,
                                                 lastModifiedDate: lastModifiedDate!,
                                                 properties: properties)
        } else {
            // TODO: !
            assert(false)
            return nil
        }
    }
    
    return DatabaseObjectSnapshot(objects: objects)
}

public func DeserializeJournalSet(fromJsonDictionary jsonDictionary: [String : Any], diffsUseJournalIdentifier: Bool = false) -> JournalSet? {
    var journals: [JournalIdentifier : Journal] = [:]
    
    for keyValue in jsonDictionary {
        let journalIdentifier = keyValue.key
        if let journalDictionary = keyValue.value as? [String : Any] {
            if let array = journalDictionary["df"] as? [ [String : Any] ] {
                let defaultIdentifier: String? = diffsUseJournalIdentifier ? journalIdentifier : nil
                let diffs: [JournalDiff] = array.map { DeserializeJournalDiff(fromJsonDictionary: $0, defaultIdentifier: defaultIdentifier)! }
                
                journals[journalIdentifier] = Journal(identifier: journalIdentifier, diffs: diffs)
            } else {
                assert(false)
                return nil
            }
        } else {
            assert(false)
            return nil
        }
    }
    
    return JournalSet(journals: journals)
}

public func DeserializeJournalDiff(fromJsonDictionary jsonDictionary: [String : Any], defaultIdentifier: String? = nil) -> JournalDiff? {
    guard let properties = jsonDictionary["pr"] as? DatabaseObjectPropertiesDictionary else { return nil }
    guard let timestampString = jsonDictionary["ts"] as? String else { return nil }
    guard let timestamp = DateFromString(timestampString) else { return nil }
    guard let identifier = defaultIdentifier ?? (jsonDictionary["_id"] as? String) else { return nil }
    
    return JournalDiff(identifier: identifier, timestamp: timestamp, properties: properties)
}
