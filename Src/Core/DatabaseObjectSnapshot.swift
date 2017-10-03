//
//  DatabaseSnapshot.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct DatabaseObjectSnapshot: Equatable {
    public var objects: [String : DatabaseObject]
    
    public init(objects: [String : DatabaseObject] = [:]) {
        self.objects = objects
    }
    
    static public func ==(lhs: DatabaseObjectSnapshot, rhs: DatabaseObjectSnapshot) -> Bool {
        return lhs.objects == rhs.objects
    }
}
