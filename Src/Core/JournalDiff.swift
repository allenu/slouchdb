//
//  JournalDiff.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct JournalDiff: Equatable {
    public let identifier: String
    public let timestamp: Date
    public let properties: DatabaseObjectPropertiesDictionary
    
    public init(identifier: String,
         timestamp: Date,
         properties: [String:String]) {
        self.identifier = identifier
        self.timestamp = timestamp
        self.properties = properties
    }

    static public func ==(lhs: JournalDiff, rhs: JournalDiff) -> Bool {
        return lhs.identifier == rhs.identifier
            && lhs.timestamp == rhs.timestamp
            && lhs.properties == rhs.properties
    }
}
