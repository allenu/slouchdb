//
//  SampleDatabaseController.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/12/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation
import SlouchDB

extension Notification.Name {
    static let didInsertPeople = Notification.Name(rawValue: "didInsertPeople")
    static let didModifyPeople = Notification.Name(rawValue: "didModifyPeople")
}

class SampleDatabaseController {
    var database: Database
    var people: [Person] = []
    
    init(database: Database) {
        self.database = database
        self.database.delegate = self
        
        loadPeople()
    }
    
    private func person(from object: DatabaseObject) -> Person {
        assert(object.identifier != DatabaseObject.kDeltaIdentifier)
        
        // Some DatabaseObjects may be incomplete because they are merely deltas but we
        // might accidentally treat them as 'inserts' if the original object does not yet
        // exist. Therefore, we must check the properties to make sure we have them all
        // or else create default values like below.
        
        let name = object.properties[Person.namePropertyKey] ?? "<name>"
        let weight = Int(object.properties[Person.weightPropertyKey] ?? "0")!
        let age = Int(object.properties[Person.agePropertyKey] ?? "20")!
        
        return Person(identifier: object.identifier,
                      name: name,
                      weight: weight,
                      age: age)
    }
    
    private func loadPeople() {
        let objects = database.fetchObjects()
        people = objects.map { person(from: $0) }
    }
    
    func add(person: Person) {
        let properties: DatabaseObjectPropertiesDictionary = [
            Person.weightPropertyKey : "\(person.weight)",
            Person.agePropertyKey : "\(person.age)",
            Person.namePropertyKey : person.name,
        ]
        let now = Date()
        let object = DatabaseObject(identifier: person.identifier,
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: properties)
        
        _ = database.insert(object: object)
    }

    func modifyPerson(identifier: String, properties: DatabaseObjectPropertiesDictionary) {
        _ = database.update(identifier: identifier, properties: properties)
    }
}

extension SampleDatabaseController: DatabaseDelegate {
    func database(_ database: Database, didUpdateWithDeltas deltas: [String : DatabaseObject]) {
        
        var modifiedPeople: [Person] = []
        var modifiedProperties: [ [String] ] = []
        var modifiedIndexes: [Int] = []
        var newPeople: [Person] = []
        let beforeCount = self.people.count

        for delta in deltas {
            let identifier = delta.key
            let object = delta.value
            
            if let index = people.index(where: { $0.identifier == identifier }) {
                // modified entry
                var person = people[index]
                var modifiedPropertiesForPerson: [String] = []
                for property in object.properties {
                    switch property.key {
                    case Person.weightPropertyKey:
                        person.weight = Int(property.value)!
                    case Person.agePropertyKey:
                        person.age = Int(property.value)!
                    case Person.namePropertyKey:
                        person.name = property.value
                        
                    default:
                        assert(false)
                    }
                    
                    modifiedPropertiesForPerson.append(property.key)
                }
                people[index] = person
                modifiedProperties.append(modifiedPropertiesForPerson)
                modifiedIndexes.append(index)
                modifiedPeople.append(person)
            } else {
                // new entry
                let person = self.person(from: object)
                newPeople.append(person)
                people.append(person)
            }
        }
        let afterCount = self.people.count

        if modifiedPeople.count > 0 {
            let modifyUserInfo: [String : Any] = ["people": modifiedPeople,
                                                  "properties" : modifiedProperties,
                                                  "indexes" : modifiedIndexes]
            NotificationCenter.default.post(name: .didModifyPeople, object: self, userInfo: modifyUserInfo)
        }

        if newPeople.count > 0 {
            let insertedUserInfo: [String : Any] = ["people": newPeople,
                                                    "range" : Range(beforeCount...afterCount-1)]
            NotificationCenter.default.post(name: .didInsertPeople, object: self, userInfo: insertedUserInfo)
        }
    }
    
    func database(_ database: Database, saveLocalJournal localJournal: Journal) {
        
    }
    func database(_ database: Database, saveJournalCache journalCache: MultiplexJournalCache) {
        
    }
    func database(_ database: Database, saveDatabaseState databaseState: DatabaseObjectState) {
        
    }
}
