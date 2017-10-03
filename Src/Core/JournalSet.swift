//
//  JournalSet.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 10/27/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct JournalSet: Equatable {
    public static func ==(lhs: JournalSet, rhs: JournalSet) -> Bool {
        return lhs.journals == rhs.journals
    }
    
    public var journals: [JournalIdentifier : Journal]
    
    public init(journals: [JournalIdentifier : Journal]) {
        self.journals = journals
    }
}

// This represents a set of single entity journals, which is applied as a patch
public typealias SingleEntityJournalPatch = JournalSet

public typealias MultiplexJournalCache = JournalSet
