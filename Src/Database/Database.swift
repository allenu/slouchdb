//
//  Database.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/3/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public protocol DatabaseDelegate: class {
    func database(_ database: Database, didUpdateWithDeltas deltas: [String : DatabaseObject])
    
    func database(_ database: Database, saveJournalCache journalCache: MultiplexJournalCache)
    func database(_ database: Database, saveDatabaseState databaseState: DatabaseObjectState)
}

public class Database {
    public var delegate: DatabaseDelegate?
    
    public var localIdentifier: JournalIdentifier
    
    public private(set) var journalCache: MultiplexJournalCache
    public private(set) var databaseObjectState: DatabaseObjectState
    
    var journalCacheDirty = false
    var databaseObjectStateDirty = false

    public init(localIdentifier: JournalIdentifier,
                cachedJournals: [JournalIdentifier : Journal] = [:],
                cachedObjects: [String : DatabaseObject] = [:],
                cachedSingleEntityJournals: [JournalIdentifier : SingleEntityJournal] = [:])
    {
        self.localIdentifier = localIdentifier
        self.journalCache = MultiplexJournalCache(journals: cachedJournals)
        
        let snapshot = DatabaseObjectSnapshot(objects: cachedObjects)
        let objectHistories = DatabaseObjectHistories(journals: cachedSingleEntityJournals)
        databaseObjectState = DatabaseObjectState(snapshot: snapshot, objectHistories: objectHistories)
    }
    
    // Serialization
    
    func save() {
        if journalCacheDirty {
            delegate?.database(self, saveJournalCache: journalCache)
            journalCacheDirty = false
        }
        if databaseObjectStateDirty {
            delegate?.database(self, saveDatabaseState: databaseObjectState)
            databaseObjectStateDirty = false
        }
    }
    
    // Merging API
    
    public func merge(multiplexJournals: [MultiplexJournal]) -> Bool {
        guard multiplexJournals.count > 0 else { return false }
        
        // Transform old into new values
        let demuxResult = DemuxJournals(multiplexJournals: multiplexJournals, multiplexJournalCache: journalCache)
        let newStateResult = GenerateDatabaseState(oldState: databaseObjectState, patch: demuxResult.singleEntityJournalPatch)
        
        journalCacheDirty = journalCacheDirty || demuxResult.journalCacheUpdated
        databaseObjectStateDirty = databaseObjectStateDirty || newStateResult.deltas.count > 0

        // Update to the new state
        journalCache = demuxResult.newMultiplexJournalCache
        databaseObjectState = newStateResult.newState
        
        var hasChanges = false
        if newStateResult.deltas.count > 0 {
            delegate?.database(self, didUpdateWithDeltas: newStateResult.deltas)
            hasChanges = true
        }
        
        return hasChanges
    }
    
    func add(diff: JournalDiff, toObjectHistoryWithIdentifier identifier: JournalIdentifier) {
        if var oldJournal = databaseObjectState.objectHistories.journals[identifier] {
            oldJournal.diffs.append(diff)
            databaseObjectState.objectHistories.journals[identifier] = oldJournal
        } else {
            databaseObjectState.objectHistories.journals[identifier] = SingleEntityJournal(identifier: identifier, diffs: [diff])
        }
    }
    
    func addToLocalJournal(diff: JournalDiff) {
        // Update the journalCache entry as well
        var tmpLocalJournal = journalCache.journals[localIdentifier] ?? Journal(identifier: localIdentifier, diffs: [])
        tmpLocalJournal.diffs.append(diff)
        journalCache.journals[localIdentifier] = tmpLocalJournal
        journalCacheDirty = true
    }
    
    // API for runtime clients
    
    public func insert(object: DatabaseObject) -> DatabaseObject {
        // Add to localJournal and history
        //
        var newObject = object
        if newObject.identifier == DatabaseObject.kUnassignedIdentifier {
            newObject.identifier = UUID().uuidString
        }
        let date = Date()
        newObject.creationDate = date
        newObject.lastModifiedDate = date
        
        let diff = JournalDiff(identifier: object.identifier,
                               timestamp: date,
                               properties: object.properties)
        addToLocalJournal(diff: diff)

        databaseObjectState.snapshot.objects[object.identifier] = newObject
        add(diff: diff, toObjectHistoryWithIdentifier: object.identifier)
        databaseObjectStateDirty = true
        
        delegate?.database(self, didUpdateWithDeltas: [object.identifier : object])
        
        return newObject
    }
    
    public func update(identifier: String, properties: DatabaseObjectPropertiesDictionary) -> DatabaseObject {
        let now = Date()
        let delta = DatabaseObject(identifier: identifier,
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: properties)

        // Add to localJournal and history
        
        if let object = fetchObject(identifier: identifier) {
            let actualDelta = ActualDelta(delta: delta, fromObject: object)

            if actualDelta.properties.count > 0 {
                let updatedObject = ObjectPlusDelta(object: object, delta: actualDelta)
                
                let diff = JournalDiff(identifier: identifier, timestamp: now, properties: actualDelta.properties)
                addToLocalJournal(diff: diff)
                
                databaseObjectState.snapshot.objects[identifier] = updatedObject
                add(diff: diff, toObjectHistoryWithIdentifier: identifier)
                databaseObjectStateDirty = true
                
                delegate?.database(self, didUpdateWithDeltas: [identifier : actualDelta])
                
                return updatedObject
            } else {
                return object
            }
        } else {
            // Entry doesn't exist yet, so we'll have to create it
            return insert(object: DatabaseObject(identifier: identifier,
                                                 creationDate: delta.creationDate,
                                                 lastModifiedDate: delta.lastModifiedDate,
                                                 properties: delta.properties))
        }
    }
    
    public func fetchObject(identifier: String) -> DatabaseObject? {
        return databaseObjectState.snapshot.objects[identifier]
    }
    
    public func fetchObjects() -> [DatabaseObject] {
        return Array(databaseObjectState.snapshot.objects.values.sorted(by: { $0.creationDate < $1.creationDate }))
    }
}
