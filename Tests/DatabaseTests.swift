//
//  DatabaseTests.swift
//  SlouchDBTests
//
//  Created by Allen Ussher on 11/4/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation
import XCTest
import Yaml
@testable import SlouchDB

class DatabaseTests: XCTestCase {
    var database: Database!
    var updateExpectation: XCTestExpectation?
    var saveDatabaseStateExpectation: XCTestExpectation?
    var saveJournalCacheExpectation: XCTestExpectation?
    var deltas: [String : DatabaseObject] = [:]
    
    var databaseObjectStateToSave: DatabaseObjectState?
    var journalCacheToSave: MultiplexJournalCache?

    override func setUp() {
        super.setUp()

        let localIdentifier = "local"
        database = Database(localIdentifier: localIdentifier)
        database.delegate = self
        
        updateExpectation = nil
        saveDatabaseStateExpectation = nil
        saveJournalCacheExpectation = nil
        deltas = [:]
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testInsertOneObject() {
        let now = Date()
        let object = DatabaseObject(identifier: "abc",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["a":"123"])
        
        updateExpectation = self.expectation(description: "Should get didUpdateWithDeltas callback")

        let newObject = database.insert(object: object)
        XCTAssertEqual(object, newObject)
        
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(deltas[object.identifier])
        XCTAssert(deltas.count == 1)
        XCTAssertEqual(deltas[object.identifier], object)

        let fetchedObject = database.fetchObject(identifier: object.identifier)
        
        XCTAssertEqual(newObject, fetchedObject)
    }

    func testModifyOneObject() {
        // Insert it
        let now = Date()
        let object = DatabaseObject(identifier: "abc",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["a":"123"])
        _ = database.insert(object: object)
        
        // Create the delta
        let delta = DatabaseObject(identifier: DatabaseObject.kDeltaIdentifier,
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: ["a":"567", "b":"foo"])
        let expectedObject = DatabaseObject(identifier: "abc",
                                            creationDate: now,
                                            lastModifiedDate: now,
                                            properties: ["a":"567", "b":"foo"])
        
        // Update it
        updateExpectation = self.expectation(description: "Should get didUpdateWithDeltas callback")

        let updatedObject = database.update(identifier: object.identifier, properties: delta.properties)
        XCTAssertEqual(updatedObject, expectedObject)

        waitForExpectations(timeout: 1.0)

        XCTAssertNotNil(deltas[object.identifier])
        XCTAssert(deltas.count == 1)
        XCTAssertEqual(deltas[object.identifier], delta)
        
        let fetchedObject = database.fetchObject(identifier: object.identifier)
        
        XCTAssertEqual(fetchedObject, expectedObject)
    }

    func testFetchMissingObject() {
        let fetchedObject = database.fetchObject(identifier: "missing")
        XCTAssertNil(fetchedObject)
    }
    
    func testInsertOneObjectAndSave() {
        let now = Date()
        let object = DatabaseObject(identifier: "abc",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["a":"123"])
        
        updateExpectation = self.expectation(description: "Should get didUpdateWithDeltas callback")
        
        _ = database.insert(object: object)
        
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache since local journal is part of it")
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(databaseObjectStateToSave!.snapshot.objects.count == 1)
        XCTAssertTrue(databaseObjectStateToSave!.objectHistories.journals.count == 1)
        XCTAssertTrue(databaseObjectStateToSave!.objectHistories.journals[object.identifier]!.diffs.count == 1)
    }

    func testModifyOneObjectAndSave() {
        // Insert it
        let now = Date()
        let object = DatabaseObject(identifier: "abc",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["a":"123"])
        _ = database.insert(object: object)

        // Clear out old dirty state
        database.save()

        // Modify it
        let delta = DatabaseObject(identifier: DatabaseObject.kDeltaIdentifier,
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: ["a":"567", "b":"foo"])
        
        _ = database.update(identifier: object.identifier, properties: delta.properties)
        
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache since local journal is part of it")
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(databaseObjectStateToSave!.snapshot.objects.count == 1)
        XCTAssertTrue(databaseObjectStateToSave!.objectHistories.journals.count == 1)
        XCTAssertTrue(databaseObjectStateToSave!.objectHistories.journals[object.identifier]!.diffs.count == 2)
    }

    func testUpdateWithNoChangeAndSave() {
        // Insert it
        let now = Date()
        let object = DatabaseObject(identifier: "abc",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["a":"123"])
        _ = database.insert(object: object)
        
        // Clear out old dirty state
        database.save()
        
        // Modify it but change a property to the same thing, which should be a no-op
        let delta = DatabaseObject(identifier: DatabaseObject.kDeltaIdentifier,
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: ["a":"123"])
        
        _ = database.update(identifier: object.identifier, properties: delta.properties)
        
        saveDatabaseStateExpectation = expectation(description: "Should NOT save database state")
        saveDatabaseStateExpectation?.isInverted = true
        saveJournalCacheExpectation = expectation(description: "Should NOT save journal cache")
        saveJournalCacheExpectation?.isInverted = true
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertTrue(databaseObjectStateToSave!.snapshot.objects.count == 1)
        XCTAssertTrue(databaseObjectStateToSave!.objectHistories.journals.count == 1)
        XCTAssertTrue(databaseObjectStateToSave!.objectHistories.journals[object.identifier]!.diffs.count == 1)
    }

    func testMergeEmpty() {
        updateExpectation = expectation(description: "Should NOT get an update since journals is empty")
        updateExpectation?.isInverted = true
        
        let multiplexJournals: [MultiplexJournal] = []
        _ = database.merge(multiplexJournals: multiplexJournals)
        
        waitForExpectations(timeout: 1.0)
        
        // Now save, we should NOT get any callback
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should NOT save database state")
        saveDatabaseStateExpectation?.isInverted = true
        saveJournalCacheExpectation = expectation(description: "Should NOT save journal cache")
        saveJournalCacheExpectation?.isInverted = true
        
        database.save()

        waitForExpectations(timeout: 1.0)
    }

    func testMergeOne() {
        updateExpectation = expectation(description: "Should get an update since journal will add one entry")
        
        let now = Date()
        var diffs: [JournalDiff] = []
        let newObject = DatabaseObject(identifier: "apple",
                                       creationDate: now,
                                       lastModifiedDate: now,
                                       properties: ["foo" : "bar"])
        let diff = JournalDiff(identifier: newObject.identifier, timestamp: Date(), properties: newObject.properties)
        diffs.append(diff)
        
        let journal = Journal(identifier: "remote", diffs: diffs)
        
        let multiplexJournals: [MultiplexJournal] = [journal]
        _ = database.merge(multiplexJournals: multiplexJournals)
        
        waitForExpectations(timeout: 1.0)
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects, [newObject.identifier : newObject])
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[newObject.identifier]!.diffs, [diff])
        XCTAssertEqual(journalCacheToSave!.journals, [journal.identifier : journal])
    }

    func testMergeTwo() {
        updateExpectation = expectation(description: "Should get an update since journal will add one entry")
        
        let now = Date()
        var appleDiffs: [JournalDiff] = []
        let apple = DatabaseObject(identifier: "apple",
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: ["foo" : "bar"])
        let appleDiff = JournalDiff(identifier: apple.identifier, timestamp: Date(), properties: apple.properties)
        appleDiffs.append(appleDiff)
        let appleJournal = Journal(identifier: "apple_remote", diffs: appleDiffs)

        var bananaDiffs: [JournalDiff] = []
        let banana = DatabaseObject(identifier: "banana",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["song" : "cruel summer"])
        let bananaDiff = JournalDiff(identifier: banana.identifier, timestamp: Date(), properties: banana.properties)
        bananaDiffs.append(bananaDiff)
        let bananaJournal = Journal(identifier: "banana_remote", diffs: bananaDiffs)

        
        let multiplexJournals: [MultiplexJournal] = [appleJournal, bananaJournal]
        _ = database.merge(multiplexJournals: multiplexJournals)
        
        waitForExpectations(timeout: 1.0)
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects, [apple.identifier : apple,
                                                                     banana.identifier : banana
                                                                     ])
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[apple.identifier]!.diffs, appleDiffs)
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[banana.identifier]!.diffs, bananaDiffs)
        XCTAssertEqual(journalCacheToSave!.journals, [appleJournal.identifier : appleJournal,
                                                      bananaJournal.identifier : bananaJournal])
    }

    func testMergeWithExistingJournalAndSave() {
        updateExpectation = expectation(description: "Should get an update since journal will add one entry")
        
        let now = Date()
        var appleDiffs: [JournalDiff] = []
        let apple = DatabaseObject(identifier: "apple",
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: ["foo" : "bar"])
        let appleDiff = JournalDiff(identifier: apple.identifier, timestamp: Date(), properties: apple.properties)
        appleDiffs.append(appleDiff)
        
        let journal = Journal(identifier: "remote", diffs: appleDiffs)
        
        let multiplexJournals: [MultiplexJournal] = [journal]
        _ = database.merge(multiplexJournals: multiplexJournals)
        
        waitForExpectations(timeout: 1.0)
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        
        database.save()

        
        // Save the first time around should give us the apple object
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects, [apple.identifier : apple])
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[apple.identifier]!.diffs, appleDiffs)
        XCTAssertEqual(journalCacheToSave!.journals, [journal.identifier : journal])
        
        databaseObjectStateToSave = nil
        journalCacheToSave = nil

        // Merge the same entries... should do nothing
        _ = database.merge(multiplexJournals: multiplexJournals)

        waitForExpectations(timeout: 1.0)

        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should NOT save database state")
        saveDatabaseStateExpectation?.isInverted = true
        saveJournalCacheExpectation = expectation(description: "Should NOT save journal cache")
        saveJournalCacheExpectation?.isInverted = true
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
    }

    func testMergeAgainWithUpdatesInSingleJournal() {
        
        updateExpectation = expectation(description: "Should get an update since journal will add one entry")
        
        let now = Date()
        var appleDiffs: [JournalDiff] = []
        let apple = DatabaseObject(identifier: "apple",
                                   creationDate: now,
                                   lastModifiedDate: now,
                                   properties: ["foo" : "bar"])
        let appleDiff = JournalDiff(identifier: apple.identifier, timestamp: Date(), properties: apple.properties)
        appleDiffs.append(appleDiff)
        
        let journal = Journal(identifier: "remote", diffs: appleDiffs)
        
        let multiplexJournals: [MultiplexJournal] = [journal]
        _ = database.merge(multiplexJournals: multiplexJournals)
        
        waitForExpectations(timeout: 1.0)
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        
        database.save()
        
        
        // Now merge with the same journal as before but with newer entries
        
        let banana = DatabaseObject(identifier: "banana",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["song" : "cruel summer"])
        let bananaDiff = JournalDiff(identifier: banana.identifier, timestamp: Date(), properties: banana.properties)

        
        let orange = DatabaseObject(identifier: "orange",
                                    creationDate: now,
                                    lastModifiedDate: now,
                                    properties: ["type" : "juice"])
        let orangeDiff = JournalDiff(identifier: orange.identifier, timestamp: Date(), properties: orange.properties)

        var newJournal = journal
        newJournal.diffs.append(bananaDiff)
        newJournal.diffs.append(orangeDiff)
        
        // Merge the same entries... should do nothing
        _ = database.merge(multiplexJournals: [newJournal])
        
        waitForExpectations(timeout: 1.0)
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        // Save should have three objects
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects, [apple.identifier : apple,
                                                                     banana.identifier : banana,
                                                                     orange.identifier : orange ])
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[apple.identifier]!.diffs, appleDiffs)
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[banana.identifier]!.diffs, [bananaDiff])
        XCTAssertEqual(databaseObjectStateToSave!.objectHistories.journals[orange.identifier]!.diffs, [orangeDiff])
        XCTAssertEqual(journalCacheToSave!.journals, [newJournal.identifier : newJournal])
    }

    func createTestDiffs() -> [JournalDiff] {
        let time1 = Date(timeIntervalSince1970: 1000)
        let time2 = Date(timeIntervalSince1970: 1001)
        let time3 = Date(timeIntervalSince1970: 1002)
        let time4 = Date(timeIntervalSince1970: 1003)
        let time5 = Date(timeIntervalSince1970: 1004)
        let time6 = Date(timeIntervalSince1970: 1005)
        
        let diff0 = JournalDiff(identifier: "apple", timestamp: time1, properties: ["a" : "1", "b" : "11", "c" : "foo", "name" : "diff0"])
        let diff1 = JournalDiff(identifier: "apple", timestamp: time2, properties: ["a" : "2", "b" : "12", "two" : "hi", "name" : "diff1"])
        let diff2 = JournalDiff(identifier: "apple", timestamp: time3, properties: ["a" : "3", "b" : "13", "name" : "diff2", "three" : "hello"])
        let diff3 = JournalDiff(identifier: "apple", timestamp: time4, properties: ["a" : "4", "b" : "14", "c" : "bar", "name" : "diff3"])
        let diff4 = JournalDiff(identifier: "apple", timestamp: time5, properties: ["a" : "yy", "b" : "xx", "d" : "dee", "name" : "diff4"])
        let diff5 = JournalDiff(identifier: "apple", timestamp: time6, properties: ["a" : "5", "b" : "16", "name" : "diff5"])
        
        return [diff0, diff1, diff2, diff3, diff4, diff5]
    }
    
    func createBananaDiffs() -> [JournalDiff] {
        let time1 = Date(timeIntervalSince1970: 1000)
        let time2 = Date(timeIntervalSince1970: 1001)
        let time3 = Date(timeIntervalSince1970: 1002)
        let time4 = Date(timeIntervalSince1970: 1003)
        let time5 = Date(timeIntervalSince1970: 1004)
        let time6 = Date(timeIntervalSince1970: 1005)
        
        let diff0 = JournalDiff(identifier: "banana", timestamp: time1, properties: ["name" : "banana_diff0", "0" : "zero"])
        let diff1 = JournalDiff(identifier: "banana", timestamp: time2, properties: ["name" : "banana_diff1", "1" : "one"])
        let diff2 = JournalDiff(identifier: "banana", timestamp: time3, properties: ["name" : "banana_diff2", "2" : "two"])
        let diff3 = JournalDiff(identifier: "banana", timestamp: time4, properties: ["name" : "banana_diff3", "3" : "three"])
        let diff4 = JournalDiff(identifier: "banana", timestamp: time5, properties: ["name" : "banana_diff4", "4" : "four"])
        let diff5 = JournalDiff(identifier: "banana", timestamp: time6, properties: ["name" : "banana_diff5", "5" : "five"])

        return [diff0, diff1, diff2, diff3, diff4, diff5]
    }
    
    func testMergeOnOlderJournal() {
        // Create journal with time 1s, 9s, and 15s
        // Apply the database
        // Create a second journal with time 2s and 12s
        // (the 12s entry overwrites something from 9s)
        // (the 2s entry overwrites something from 1s)

        let diffs = createTestDiffs()
        let journal1 = Journal(identifier: "journal1", diffs: [diffs[0], diffs[3]])
        let journal2 = Journal(identifier: "journal2", diffs: [diffs[1], diffs[5]])
        let journal3 = Journal(identifier: "journal3", diffs: [diffs[2], diffs[4]])
        
        
        //
        // Apply journal 1
        //
        _ = database.merge(multiplexJournals: [journal1])
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "4",
                                                                                           "b" : "14",
                                                                                           "c" : "bar",
                                                                                           "name" :  "diff3"])

        
        
        //
        // Apply journal 2
        //
        _ = database.merge(multiplexJournals: [journal2])
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "5",
                                                                                           "b" : "16",
                                                                                           "c" : "bar",
                                                                                           "two" : "hi",
                                                                                           "name" :  "diff5"])

        
        
        //
        // Apply journal 3
        //
        _ = database.merge(multiplexJournals: [journal3])
        
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "5",
                                                                                           "b" : "16",
                                                                                           "c" : "bar",
                                                                                           "d" : "dee",
                                                                                           "two" : "hi",
                                                                                           "three" : "hello",
                                                                                           "name" :  "diff5"])

    }
    
    func testMergeManyAtOnce() {
        // Create journal with time 1s, 9s, and 15s
        // Apply the database
        // Create a second journal with time 2s and 12s
        // (the 12s entry overwrites something from 9s)
        // (the 2s entry overwrites something from 1s)
        
        let diffs = createTestDiffs()
        let journal1 = Journal(identifier: "journal1", diffs: [diffs[0], diffs[3]])
        let journal2 = Journal(identifier: "journal2", diffs: [diffs[1], diffs[5]])
        let journal3 = Journal(identifier: "journal3", diffs: [diffs[2], diffs[4]])
        
        
        //
        // Apply journal 1
        //
        _ = database.merge(multiplexJournals: [journal1, journal2, journal3])
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "5",
                                                                                           "b" : "16",
                                                                                           "c" : "bar",
                                                                                           "d" : "dee",
                                                                                           "two" : "hi",
                                                                                           "three" : "hello",
                                                                                           "name" :  "diff5"])

    }
    
    func testMergeAdditive() {
        // Create journal with time 1s, 9s, and 15s
        // Apply the database
        // Create a second journal with time 2s and 12s
        // (the 12s entry overwrites something from 9s)
        // (the 2s entry overwrites something from 1s)
        
        // We'll add onto the same journal, note identifier stays the same
        let diffs = createTestDiffs()
        let journal1 = Journal(identifier: "journal1", diffs: [diffs[0], diffs[1]])
        let journal2 = Journal(identifier: "journal1", diffs: [diffs[0], diffs[1], diffs[2], diffs[3]])
        let journal3 = Journal(identifier: "journal1", diffs: [diffs[0], diffs[1], diffs[2], diffs[3], diffs[4], diffs[5]])

        
        //
        // Apply journal 1
        //
        _ = database.merge(multiplexJournals: [journal1])
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "2",
                                                                                           "b" : "12",
                                                                                           "c" : "foo",
                                                                                           "two" : "hi",
                                                                                           "name" :  "diff1"])
        
        //
        // Apply journal 2
        //
        _ = database.merge(multiplexJournals: [journal2])
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "4",
                                                                                           "b" : "14",
                                                                                           "c" : "bar",
                                                                                           "two" : "hi",
                                                                                           "three" : "hello",
                                                                                           "name" :  "diff3"])

        //
        // Apply journal 3
        //
        _ = database.merge(multiplexJournals: [journal3])
        
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "5",
                                                                                           "b" : "16",
                                                                                           "c" : "bar",
                                                                                           "d" : "dee",
                                                                                           "two" : "hi",
                                                                                           "three" : "hello",
                                                                                           "name" :  "diff5"])
    }
    
    func testMergeWithTwoIntertwinedJournals() {
        let appleDiffs = createTestDiffs()
        let bananaDiffs = createBananaDiffs()
        
        let journal1 = Journal(identifier: "journal1", diffs: [appleDiffs[0], bananaDiffs[1], bananaDiffs[2]])
        let journal2 = Journal(identifier: "journal2", diffs: [appleDiffs[1], bananaDiffs[0], appleDiffs[2]])
        let journal3 = Journal(identifier: "journal3", diffs: [appleDiffs[3], bananaDiffs[5], appleDiffs[4]])
        let journal4 = Journal(identifier: "journal4", diffs: [bananaDiffs[3], bananaDiffs[4], appleDiffs[5]])
        
        _ = database.merge(multiplexJournals: [journal1, journal2])

        _ = database.merge(multiplexJournals: [journal4, journal3])

        // After saving, we should have the final version of both
        updateExpectation = nil
        saveDatabaseStateExpectation = expectation(description: "Should save database state")
        saveJournalCacheExpectation = expectation(description: "Should save journal cache")
        database.save()
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["apple"]!.properties, [ "a" : "5",
                                                                                           "b" : "16",
                                                                                           "c" : "bar",
                                                                                           "d" : "dee",
                                                                                           "two" : "hi",
                                                                                           "three" : "hello",
                                                                                           "name" :  "diff5"])

        XCTAssertEqual(databaseObjectStateToSave!.snapshot.objects["banana"]!.properties, [ "name" : "banana_diff5",
                                                                                            "0" : "zero",
                                                                                            "1" : "one",
                                                                                            "2" : "two",
                                                                                            "3" : "three",
                                                                                            "4" : "four",
                                                                                            "5" : "five",
                                                                                            ])
    }
}

extension DatabaseTests: DatabaseDelegate {
    func database(_ database: Database, didUpdateWithDeltas deltas: [String : DatabaseObject]) {
        self.deltas = deltas
        updateExpectation?.fulfill()
    }

    func database(_ database: Database, saveDatabaseState databaseState: DatabaseObjectState) {
        databaseObjectStateToSave = databaseState
        saveDatabaseStateExpectation?.fulfill()
    }
    
    func database(_ database: Database, saveJournalCache journalCache: MultiplexJournalCache) {
        journalCacheToSave = journalCache
        saveJournalCacheExpectation?.fulfill()
    }
}
