//
//  GenerateDatabaseStateTests.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/3/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import XCTest
import Yaml
@testable import SlouchDB


class GenerateDatabaseStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func runInputOutputTests(named name: String) {
        let path = Bundle(for: type(of: self)).path(forResource: name, ofType: "yml")!
        var yaml: Yaml!
        do {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            yaml = try Yaml.load(text)
        } catch {
            print("Error with yaml \(error)")
            assert(false)
        }
        
        guard let yamlDictionary: [Yaml : Yaml] = yaml.dictionary else { assert(false) }
        
        guard let inputDictionary = yamlDictionary["input"]?.dictionary else { assert(false) }
        guard let outputDictionary = yamlDictionary["output"]?.dictionary else { assert(false) }

        guard let oldStateYaml = inputDictionary["oldState"] else { assert(false) }
        guard let inputPatchYaml = inputDictionary["patch"] else { assert(false) }

        guard let deltasYaml = outputDictionary["deltas"] else { assert(false) }
        guard let newStateYaml = outputDictionary["newState"] else { assert(false) }

        guard let oldState = DeserializeDatabaseState(fromYaml: oldStateYaml) else { assert(false) }
        guard let inputPatch = DeserializeJournalSet(yaml: inputPatchYaml) else { assert(false) }
        
        guard let deltas = DeserializeDatabaseObjects(fromYaml: deltasYaml) else { assert(false) }
        guard let newState = DeserializeDatabaseState(fromYaml: newStateYaml) else { assert(false) }

        let result = GenerateDatabaseState(oldState: oldState, patch: inputPatch)
  
        XCTAssertEqual(result.newState.snapshot, newState.snapshot)
        XCTAssertEqual(result.newState.objectHistories, newState.objectHistories)
        XCTAssertEqual(result.newState, newState)

        XCTAssertEqual(result.deltas, deltas)
    }
    
    func testBasic() {
        runInputOutputTests(named: "test_gen_example")
    }

    func testAddOneToEmpty() {
        runInputOutputTests(named: "gen_empty_add_one")
    }

    func testModifyOneProperty() {
        runInputOutputTests(named: "gen_change_single_property")
    }
}
