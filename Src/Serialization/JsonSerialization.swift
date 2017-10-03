//
//  JsonSerialization.swift
//  SlouchDB_Mac-Unit-Tests
//
//  Created by Allen Ussher on 11/18/17.
//

import Foundation

public func SerializeJournalDiff(journalDiff: JournalDiff, includeIdentifier: Bool = true) -> [String : Any] {
    var dictionary: [String : Any] = [:]
    
    if includeIdentifier {
        dictionary["_id"] = journalDiff.identifier
    }
    dictionary["ts"] = StringFromDate(journalDiff.timestamp)
    dictionary["pr"] = journalDiff.properties
    
    return dictionary
}

public func SerializeJournalSet(journalSet: JournalSet, diffsShouldHaveIdentifier: Bool = true) -> [String : Any] {
    var dictionary: [String : Any] = [:]
    
    for keyValue in journalSet.journals {
        let journalIdentifier = keyValue.key
        let journal = keyValue.value
        
        var journalDictionary: [String : Any] = [:]
        
        let journalDiffDictionaries = journal.diffs.map {
            SerializeJournalDiff(journalDiff: $0, includeIdentifier: diffsShouldHaveIdentifier) }
        journalDictionary["df"] = journalDiffDictionaries
        
        dictionary[journalIdentifier] = journalDictionary
    }
    
    return dictionary
}

public func SerializeDatabaseSnapshot(snapshot: DatabaseObjectSnapshot) -> [String : Any] {
    var dictionary: [String : Any] = [:]
    
    for keyValue in snapshot.objects {
        let objectIdentifier = keyValue.key
        let ignoredProperties = [DatabaseObject.kIdentifierPropertyKey] // already included in key
        var objectProperties = keyValue.value.properties.filter({ ignoredProperties.contains($0.key) == false })
        
        objectProperties[DatabaseObject.kCreationDatePropertyKey] = StringFromDate(keyValue.value.creationDate)
        objectProperties[DatabaseObject.kLastModifiedDatePropertyKey] = StringFromDate(keyValue.value.lastModifiedDate)

        dictionary[objectIdentifier] = objectProperties
    }
    
    return dictionary
}

public func SerializeDatabaseState(state: DatabaseObjectState) -> [String : Any] {
    var dictionary: [String : Any] = [:]
    
    dictionary["snapshot"] = SerializeDatabaseSnapshot(snapshot: state.snapshot)
    dictionary["histories"] = SerializeJournalSet(journalSet: state.objectHistories, diffsShouldHaveIdentifier: false)
    
    return dictionary
}
