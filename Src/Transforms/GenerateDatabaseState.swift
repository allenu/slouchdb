//
//  GenerateDatabaseState.swift
//  SlouchDB
//
//  Created by Allen Ussher on 10/24/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

func DeltaFromDiffs(diffs: [JournalDiff]) -> DatabaseObject {
    var creationDate: Date? = nil
    var identifier: String = DatabaseObject.kDeltaIdentifier
    if let firstDiff = diffs.first {
        creationDate = firstDiff.timestamp
        identifier = firstDiff.identifier
    }
    creationDate = creationDate ?? Date()

    var lastModifiedDate: Date? = nil
    if let lastDiff = diffs.last {
        lastModifiedDate = lastDiff.timestamp
    }
    lastModifiedDate = lastModifiedDate ?? creationDate

    var object = DatabaseObject(identifier: identifier,
                                creationDate: creationDate!,
                                lastModifiedDate: lastModifiedDate!)
    
    for diff in diffs {
        object.properties = object.properties.merging(diff.properties, uniquingKeysWith: { _, new in new })
    }
    return object
}

func ObjectPlusDelta(object: DatabaseObject, delta: DatabaseObject) -> DatabaseObject {
    return DatabaseObject(identifier: object.identifier,
                          creationDate: object.creationDate,
                          lastModifiedDate: delta.lastModifiedDate,
                          properties: object.properties.merging(delta.properties, uniquingKeysWith: { _, new in new }))
}

func ActualDelta(delta: DatabaseObject, fromObject object: DatabaseObject) -> DatabaseObject {
    var newDelta = delta
    
    for keyValue in newDelta.properties {
        if let oldValue = object.properties[keyValue.key] {
            if oldValue == keyValue.value {
                newDelta.properties.removeValue(forKey: keyValue.key)
            }
        }
    }
    
    if newDelta.properties.count > 0 {
        newDelta.lastModifiedDate = delta.lastModifiedDate
    } else {
        newDelta.lastModifiedDate = object.lastModifiedDate
    }
    
    return newDelta
}

func DeltaFromObjectComparison(newObject: DatabaseObject, oldObject: DatabaseObject) -> DatabaseObject {
    let lastModifiedDate: Date = oldObject.lastModifiedDate > newObject.lastModifiedDate ? oldObject.lastModifiedDate : newObject.lastModifiedDate
    
    var delta = DatabaseObject(identifier: oldObject.identifier,
                               creationDate: oldObject.creationDate,
                               lastModifiedDate: lastModifiedDate
                               )
    for keyValue in newObject.properties {
        if let oldValue = oldObject.properties[keyValue.key] {
            if keyValue.value != oldValue {
                delta.properties[keyValue.key] = keyValue.value
            }
        } else {
            // Doesn't exist in old object, so it's a new one
            delta.properties[keyValue.key] = keyValue.value
        }
    }
    return delta
}

public func GenerateDatabaseState(oldState: DatabaseObjectState, patch: SingleEntityJournalPatch) -> (newState: DatabaseObjectState, deltas: [String : DatabaseObject]) {
    var snapshot = oldState.snapshot // We'll build off the old one
    var objectHistories = oldState.objectHistories  // We'll build off the old one
    var deltas: [String : DatabaseObject] = [:]
    
    for singleEntityJournalKeyValue in patch.journals {
        let entityIdentifier = singleEntityJournalKeyValue.value.identifier
        let newDiffs = singleEntityJournalKeyValue.value.diffs
        
        if let firstNewDiff = newDiffs.first {
            let oldDiffs: [JournalDiff]
            if let oldSingleEntityJournal = oldState.objectHistories.journals[entityIdentifier] {
                oldDiffs = oldSingleEntityJournal.diffs
            } else {
                oldDiffs = []
            }
            
            // Either of two things can happen:
            // 1. the easy case, the oldest entry in the newDiffs is newer than the newest
            //    entry in the old diffs. We just have to append newDiffs to oldDiffs and
            //    play back the newDiffs to change the old entity state.
            // 2. the harder case, we need to merge the contents of newDiffs and oldDiffs.
            //     After which, we recreate the entity from scratch.
            let doAppendOperation: Bool
            if let lastOldDiff = oldDiffs.last {
                doAppendOperation = lastOldDiff.timestamp < firstNewDiff.timestamp
            } else {
                // oldDiffs is empty
                doAppendOperation = true
            }
            
            // Create an object that represents the new entity
            let newEntity: DatabaseObject

            let mergedDiffs: [JournalDiff]
            let entityDelta: DatabaseObject // Represents the delta from the old entity
            let now = Date()
            let newEmptyObject = DatabaseObject(identifier: entityIdentifier,
                                                creationDate: now,
                                                lastModifiedDate: now)
            let oldObject = snapshot.objects[entityIdentifier] ?? newEmptyObject
            if doAppendOperation {
                mergedDiffs = oldDiffs + newDiffs
                
                // Determine delta from newDiffs
                entityDelta = DeltaFromDiffs(diffs: newDiffs)
                newEntity = ObjectPlusDelta(object: oldObject, delta: entityDelta)
            } else {
                mergedDiffs = (oldDiffs + newDiffs).sorted(by: { $0.timestamp < $1.timestamp })
                
                // Create the new entity completely from scratch
                newEntity = DeltaFromDiffs(diffs: mergedDiffs)
                entityDelta = DeltaFromObjectComparison(newObject: newEntity, oldObject: oldObject)
            }
            
            // If there is at least one property that changed, save it to our deltas
            if entityDelta.properties.count > 0 {
                deltas[entityIdentifier] = entityDelta
            }
            
            // Create new objectHistories for this entity
            var singleEntityJournal = objectHistories.journals[entityIdentifier] ?? SingleEntityJournal(identifier: entityIdentifier, diffs: [])
            singleEntityJournal.diffs = mergedDiffs
            
            objectHistories.journals[entityIdentifier] = singleEntityJournal
            snapshot.objects[entityIdentifier] = newEntity
        } else {
            // newDiffs is empty, nothing to do!
        }
    }
    
    return (newState: DatabaseObjectState(snapshot: snapshot, objectHistories: objectHistories), deltas: deltas)
}
