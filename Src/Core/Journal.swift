//
//  Journal.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public typealias JournalIdentifier = String

public struct Journal: Equatable {
    public let identifier: JournalIdentifier
    public var diffs: [JournalDiff]
    
    public init(identifier: JournalIdentifier, diffs: [JournalDiff]) {
        self.identifier = identifier
        self.diffs = diffs
    }
    
    static public func ==(lhs: Journal, rhs: Journal) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.diffs == rhs.diffs
    }
}

public typealias MultiplexJournal = Journal

public typealias SingleEntityJournal = Journal
