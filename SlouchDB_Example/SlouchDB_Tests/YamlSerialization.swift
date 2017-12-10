//
//  Serialization.swift
//  SlouchDB
//
//  Created by Allen Ussher on 10/28/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation
import SlouchDB
import Yaml

public func StringFromYaml(yaml: Yaml) -> String {
    if let value = yaml.int {
        return "\(value)"
    } else if let value = yaml.bool {
        return "\(value)"
    } else if let value = yaml.string {
        return value
    } else {
        assert(false)
        return ""
    }
}

public func DeserializeJournalDiff(yaml: Yaml) -> JournalDiff? {
    guard let yamlDictionary = yaml.dictionary else { return nil }
    
    let yamlKey: Yaml = Yaml(stringLiteral: DatabaseObject.kIdentifierPropertyKey)
    guard let identifier = yamlDictionary[yamlKey]!.string else { return nil }
    guard let timestampString = yamlDictionary["ts"]!.string else { return nil }
    guard let propertiesDictionary = yamlDictionary["pr"]!.dictionary else { return nil }
    
    guard let timestamp = DateFromString(timestampString) else { return nil }

    var properties: DatabaseObjectPropertiesDictionary = [:]
    for keyYaml in propertiesDictionary.keys {
        if let key = keyYaml.string {
            if let value = propertiesDictionary[keyYaml]?.int {
                properties[key] = "\(value)"
            } else if let value = propertiesDictionary[keyYaml]?.bool {
                properties[key] = "\(value)"
            } else if let value = propertiesDictionary[keyYaml]?.string {
                properties[key] = value
            } else {
                assert(false)
                return nil
            }
        } else {
            assert(false)
            return nil
        }
    }
    
    return JournalDiff(identifier: identifier, timestamp: timestamp, properties: properties)
}

public func DeserializeJournal(yaml: Yaml) -> Journal? {
    guard let identifier = yaml[Yaml(stringLiteral: DatabaseObject.kIdentifierPropertyKey)].string else  { return nil }
    guard let diffsYaml = yaml["df"].array else { return nil }
    
    let diffs = diffsYaml.map { DeserializeJournalDiff(yaml: $0) }.flatMap { $0 }
    
    return Journal(identifier: identifier, diffs: diffs)
}

public func DeserializeJournalSet(yaml: Yaml) -> JournalSet? {
    guard let dictionary = yaml.dictionary else { return nil }
    
    var journals: [String : Journal] = [:]
    
    for keyValue in dictionary {
        let journalIdentifier = keyValue.key.string!
        let journal = DeserializeJournal(yaml: keyValue.value)
        journals[journalIdentifier] = journal
    }
//
//    if let journalsYaml = dictionary["jr"]?.array {
//        for journalYaml in journalsYaml {
//            if let journal = DeserializeJournal(yaml: journalYaml) {
//                journals[journal.identifier] = journal
//            } else {
//                assert(false)
//                return nil
//            }
//        }
//    } else {
//        assert(false)
//    }
    
    return JournalSet(journals: journals)
}

public func DeserializeDatabaseState(fromYaml yaml: Yaml) -> DatabaseObjectState? {
    guard let dictionary = yaml.dictionary else { return nil }
    
    // Load snapshot objects
    guard let snapshotDictionary = dictionary["snapshot"]?.dictionary else { return nil }
    guard let objectsYaml = snapshotDictionary["objects"] else { return nil }
    
    let objects = DeserializeDatabaseObjects(fromYaml: objectsYaml)!
    let snapshot = DatabaseObjectSnapshot(objects: objects)
    
    // Load history journals
    guard let historyDictionary = dictionary["histories"]?.dictionary else { return nil }
    var journals: [JournalIdentifier : Journal] = [:]
    for keyValue in historyDictionary {
        let journalIdentifier = keyValue.key.string!
        let journal = DeserializeJournal(yaml: keyValue.value)
        
        journals[journalIdentifier] = journal
    }
    
    let objectHistories = DatabaseObjectHistories(journals: journals)
    
    return DatabaseObjectState(snapshot: snapshot, objectHistories: objectHistories)
}

public func DeserializeDatabaseObjects(fromYaml yaml: Yaml) -> [String : DatabaseObject]? {
    if let objectsDictionary = yaml.dictionary {
        var objects: [String : DatabaseObject] = [:]
        for keyValue in objectsDictionary {
            let objectIdentifier = keyValue.key.string!
            if let objectProperties = keyValue.value.dictionary {
                var properties: DatabaseObjectPropertiesDictionary = [:]
                
                for propertyKeyValue in objectProperties {
                    properties[propertyKeyValue.key.string!] = StringFromYaml(yaml: propertyKeyValue.value)
                }
                
                var creationDate: Date!
                if let creationDateString = properties[DatabaseObject.kCreationDatePropertyKey] {
                    creationDate = DateFromString(creationDateString)
                }
                let now = Date()
                creationDate = creationDate ?? now

                var lastModifiedDate: Date!
                if let lastModifiedDateString = properties[DatabaseObject.kLastModifiedDatePropertyKey] {
                    lastModifiedDate = DateFromString(lastModifiedDateString)
                }
                lastModifiedDate = lastModifiedDate ?? creationDate

                objects[objectIdentifier] = DatabaseObject(identifier: objectIdentifier,
                                                           creationDate: creationDate,
                                                           lastModifiedDate: lastModifiedDate,
                                                           properties: properties)
            }
        }
        return objects
    }
    return nil
}
