//
//  DemuxJournals.swift
//  SlouchDB
//
//  Created by Allen Ussher on 10/24/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public func DemuxJournals(multiplexJournals: [MultiplexJournal], multiplexJournalCache: MultiplexJournalCache) -> (singleEntityJournalPatch: SingleEntityJournalPatch, newMultiplexJournalCache: MultiplexJournalCache, journalCacheUpdated: Bool) {
    
    // Given existing cache and the new multiplex journals, extract only the newest diffs and
    // put them all into a single diff array.
    var allNewestDiffs: [JournalDiff] = []
    for multiplexJournal in multiplexJournals {
        let cachedMultiplexJournal: [JournalDiff] = multiplexJournalCache.journals[multiplexJournal.identifier]?.diffs ?? []
        
        // Copy only the newest diffs
        let newestDiffs = multiplexJournal.diffs.dropFirst(cachedMultiplexJournal.count)
        
        allNewestDiffs.append(contentsOf: newestDiffs)
    }
    
    // Take all the newest diffs and split them up into journals for each entity
    var singleEntityJournals: [JournalIdentifier : SingleEntityJournal] = [:]
    for diff in allNewestDiffs {
        var targetSingleEntityJournal: SingleEntityJournal
        if let singleEntityJournal = singleEntityJournals[diff.identifier] {
            targetSingleEntityJournal = singleEntityJournal
            targetSingleEntityJournal.diffs.append(diff)
        } else {
            targetSingleEntityJournal = SingleEntityJournal(identifier: diff.identifier, diffs: [diff])
        }
        
        // Replace the entry with the updated one
        singleEntityJournals[targetSingleEntityJournal.identifier] = targetSingleEntityJournal
    }
    
    // Sort all of the diffs in each single entity journal
    for keyValuePair in singleEntityJournals {
        var singleEntityJournal = keyValuePair.value
        let sortedDiffs = singleEntityJournal.diffs.sorted(by: { $0.timestamp < $1.timestamp })
        singleEntityJournal.diffs = sortedDiffs

        singleEntityJournals[keyValuePair.key] = singleEntityJournal
    }

    // Create the "patch" which is just all of the single entity journals since the last cache state
    let singleEntityJournalPatch = SingleEntityJournalPatch(journals: singleEntityJournals)
    
    // Replace whatever is in the cache
    var newMultiplexJournalCache = multiplexJournalCache
    var journalCacheUpdated = false
    for multiplexJournal in multiplexJournals {
        if let oldJournal = newMultiplexJournalCache.journals[multiplexJournal.identifier] {
            let journalWasUpdated = oldJournal.diffs.count < multiplexJournal.diffs.count
            journalCacheUpdated = journalCacheUpdated || journalWasUpdated
        } else {
            // Journal didn't exist yet, so this is definitely an update
            journalCacheUpdated = true
        }
        newMultiplexJournalCache.journals[multiplexJournal.identifier] = multiplexJournal
    }
    
    return (singleEntityJournalPatch: singleEntityJournalPatch, newMultiplexJournalCache: newMultiplexJournalCache, journalCacheUpdated: journalCacheUpdated)
}
