//
//  DatabaseState.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct DatabaseObjectState: Equatable {
    public var snapshot: DatabaseObjectSnapshot
    public var objectHistories: DatabaseObjectHistories
    
    public init(snapshot: DatabaseObjectSnapshot, objectHistories: DatabaseObjectHistories) {
        self.snapshot = snapshot
        self.objectHistories = objectHistories
    }
    
    static public func ==(lhs: DatabaseObjectState, rhs: DatabaseObjectState) -> Bool {
        return lhs.snapshot == rhs.snapshot && lhs.objectHistories == rhs.objectHistories
    }
}

public typealias DatabaseObjectHistories = JournalSet
