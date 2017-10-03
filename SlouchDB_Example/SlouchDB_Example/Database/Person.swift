//
//  Person.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/11/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

struct Person {
    let identifier: String
    var name: String
    var weight: Int
    var age: Int
    
    static let namePropertyKey = "name"
    static let weightPropertyKey = "weight"
    static let agePropertyKey = "age"
}

extension Person: Hashable {
    static func ==(left: Person, right: Person) -> Bool {
        return left.identifier == right.identifier
    }

    var hashValue: Int {
        return self.identifier.hashValue
    }
}
