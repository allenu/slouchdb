//
//  DatabaseObject.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public typealias DatabaseObjectPropertiesDictionary = [String : String]

public struct DatabaseObject: Equatable {
    public static let kUnassignedIdentifier = "unassigned"
    public static let kDeltaIdentifier = "delta"
    public static let kIdentifierPropertyKey = "_id"
    public static let kDeletedPropertyKey = "_de"
    public static let kCreationDatePropertyKey = "_cd"
    public static let kLastModifiedDatePropertyKey = "_lm"

    public var properties: DatabaseObjectPropertiesDictionary
    
    public var identifier: String = kUnassignedIdentifier
    public var creationDate: Date
    public var lastModifiedDate: Date
    
    public init(identifier: String? = nil,
                creationDate: Date,
                lastModifiedDate: Date,
                properties: DatabaseObjectPropertiesDictionary = [:]) {
        let ignoredPropertyKeys = [DatabaseObject.kIdentifierPropertyKey,
                                   DatabaseObject.kCreationDatePropertyKey,
                                   DatabaseObject.kLastModifiedDatePropertyKey]
        
        if let identifier = identifier {
            self.identifier = identifier
        } else if let identifier = properties[DatabaseObject.kIdentifierPropertyKey] {
            self.identifier = identifier
        }
        
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate

        self.properties = properties.filter { ignoredPropertyKeys.contains($0.key) == false }
    }
    
    static public func ==(lhs: DatabaseObject, rhs: DatabaseObject) -> Bool {
        return lhs.properties == rhs.properties
    }
}
