//
//  SerializationTests.swift
//  SlouchDB_Mac
//
//  Created by Allen Ussher on 11/7/17.
//

import Foundation
import XCTest
import Yaml
import SlouchDB

class SerializationTests: XCTestCase {
    
    func testDeserializeDatabaseSnapshot() {
        let url = Bundle(for: type(of: self)).url(forResource: "DatabaseSnapshot_Example", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let object = try! JSONSerialization.jsonObject(with: data)
        let jsonDictionary = object as! [String : Any]
        
        let databaseSnapshot = DeserializeDatabaseSnapshot(fromJsonDictionary: jsonDictionary)
        
        // TODO: validate databaseSnapshot
        _ = databaseSnapshot
    }

    func testDeserializeDatabaseHistory() {
        let url = Bundle(for: type(of: self)).url(forResource: "DatabaseHistory_Example", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let object = try! JSONSerialization.jsonObject(with: data)
        let jsonDictionary = object as! [String : Any]

        let databaseHistory = DeserializeJournalSet(fromJsonDictionary: jsonDictionary)
        
        // TODO: validate databaseHistory
        _ = databaseHistory
    }

    func testDeserializeDatabaseState() {
        let url = Bundle(for: type(of: self)).url(forResource: "DatabaseState_Example", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let object = try! JSONSerialization.jsonObject(with: data)
        let jsonDictionary = object as! [String : Any]

        let databaseState = DeserializeDatabaseState(fromJsonDictionary: jsonDictionary)

        // TODO: validate databaseState
        _ = databaseState
    }

    func testSerializeDatabaseState() {
        let url = Bundle(for: type(of: self)).url(forResource: "DatabaseState_Example", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let object = try! JSONSerialization.jsonObject(with: data)
        let jsonDictionary = object as! [String : Any]
        
        let databaseState = DeserializeDatabaseState(fromJsonDictionary: jsonDictionary)!
        
        let databaseStateDictionary = SerializeDatabaseState(state: databaseState)
        let jsonData = try! JSONSerialization.data(withJSONObject: databaseStateDictionary)

        // TODO: validate databaseStateDictionary
        _ = jsonData

        //let string = String(data: jsonData, encoding: String.Encoding.utf8) as String!
        //print("data: \(string)")
    }
}
