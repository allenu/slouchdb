//
//  DemuxJournalsTests.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 10/26/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import XCTest
import Yaml
import SlouchDB

class DemuxJournalsTests: XCTestCase {
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

        guard let inputJournalYamls = inputDictionary["jr"]?.array else { assert(false) }
        guard let inputCacheYaml = inputDictionary["cache"] else { assert(false) }
        guard let outputPatchYaml = outputDictionary["patch"] else { assert(false) }
        guard let outputCacheYaml = outputDictionary["cache"] else { assert(false) }

        var inputJournals: [Journal] = []
        for inputJournalYaml in inputJournalYamls {
            if let journal = DeserializeJournal(yaml: inputJournalYaml) {
                inputJournals.append(journal)
            } else {
                assert(false)
            }
        }
        
        let inputCache = DeserializeJournalSet(yaml: inputCacheYaml)!
        let outputCache = DeserializeJournalSet(yaml: outputCacheYaml)!
        let outputPatch = DeserializeJournalSet(yaml: outputPatchYaml)!
        
        let result = DemuxJournals(multiplexJournals: inputJournals, multiplexJournalCache: inputCache)
        XCTAssertEqual(result.singleEntityJournalPatch, outputPatch)
        XCTAssertEqual(result.newMultiplexJournalCache, outputCache)
    }
    
    func testAddOne() {
        runInputOutputTests(named: "test_add_one")
    }
    
    func testModifyOneField() {
        runInputOutputTests(named: "test_modify_one_field")
    }
    
    func testAddOneToNoCaches() {
        runInputOutputTests(named: "test_add_one_to_no_caches")
    }

    func testIgnoreOldDiffs() {
        runInputOutputTests(named: "test_ignore_old_diffs")
    }

    func testMergeInputJournals() {
        runInputOutputTests(named: "test_merge_input_journals")
    }

    // MARK: Insert Tests
    
    func testEmptyInputsShouldOutputNothing() {
        let multiplexJournals: [MultiplexJournal] = []
        let multiplexJournalCache = MultiplexJournalCache(journals: [:])
        
        let result = DemuxJournals(multiplexJournals: multiplexJournals, multiplexJournalCache: multiplexJournalCache)
        XCTAssertEqual(result.newMultiplexJournalCache.journals.count, 0)
        XCTAssertEqual(result.singleEntityJournalPatch.journals.count, 0)
    }
}

