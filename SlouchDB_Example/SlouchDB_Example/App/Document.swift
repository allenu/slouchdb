//
//  Document.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/5/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Cocoa
import SlouchDB

class Document: NSDocument {
    var databaseController: SampleDatabaseController
    var localIdentifier: String
    
    var syncState: SyncState = SyncState()
    var localFolder: URL
    
    // Maps user Ids to local identifiers used. Last one is the latest identifier.
    let userIdentifier: String
    var localIdentifierMapping: [String : [String]] = [:]

    override init() {
        // Get local user Id
        if let userIdentifier = UserDefaults.standard.string(forKey: "userIdentifier") {
            self.userIdentifier = userIdentifier
        } else {
            self.userIdentifier = UUID().uuidString
            UserDefaults.standard.set(self.userIdentifier, forKey: "userIdentifier")
        }
        
        // Create a new local identifier and add it to the list
        localIdentifier = UUID().uuidString
        localIdentifierMapping[self.userIdentifier] = [ localIdentifier ]
        
        let database = Database(localIdentifier: localIdentifier)
        databaseController = SampleDatabaseController(database: database)
        
        let applicationSupportUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let syncFolderUrl = applicationSupportUrl.appendingPathComponent("sync")
        localFolder = syncFolderUrl.appendingPathComponent("localFolder", isDirectory: true)

        try! FileManager.default.createDirectory(at: localFolder, withIntermediateDirectories: true, attributes: nil)
        
        super.init()
        // Add your subclass-specific initialization here.
        
    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        self.addWindowController(windowController)
    }

    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        let snapshotDictionary = SerializeDatabaseSnapshot(snapshot: databaseController.database.databaseObjectState.snapshot)
        let snapshotData = try JSONSerialization.data(withJSONObject: snapshotDictionary, options: .prettyPrinted)
        let snapshotFileWrapper = FileWrapper(regularFileWithContents: snapshotData)

        let historiesDictionary = SerializeJournalSet(journalSet: databaseController.database.databaseObjectState.objectHistories, diffsShouldHaveIdentifier: false)
        let historiesData = try JSONSerialization.data(withJSONObject: historiesDictionary, options: .prettyPrinted)
        let historiesFileWrapper = FileWrapper(regularFileWithContents: historiesData)

        let journalsDictionary = SerializeJournalSet(journalSet: databaseController.database.journalCache)
        let journalsData = try JSONSerialization.data(withJSONObject: journalsDictionary, options: .prettyPrinted)
        let journalsFileWrapper = FileWrapper(regularFileWithContents: journalsData)

        let identifiersData = try JSONSerialization.data(withJSONObject: localIdentifierMapping, options: .prettyPrinted)
        let identifiersFileWrapper = FileWrapper(regularFileWithContents: identifiersData)
        
        let syncStateDictionary = syncState.toDictionary()
        let syncStateData = try JSONSerialization.data(withJSONObject: syncStateDictionary, options: .prettyPrinted)
        let syncStateFileWrapper = FileWrapper(regularFileWithContents: syncStateData)

        let documentFileWrapper = FileWrapper(directoryWithFileWrappers: ["snapshot.json" : snapshotFileWrapper,
                                                                                "histories.json" : historiesFileWrapper,
                                                                                "journals.json" : journalsFileWrapper,
                                                                                "syncState.json" : syncStateFileWrapper,
                                                                                "identifiers.json" : identifiersFileWrapper])
        return documentFileWrapper
    }

    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        var snapshot: DatabaseObjectSnapshot? = nil
        var histories: DatabaseObjectHistories? = nil
        var journalCache: MultiplexJournalCache? = nil
        var syncState: SyncState? = nil
        var localIdentifierMapping: [String : [String] ]? = nil

        if let subFileWrappers = fileWrapper.fileWrappers {
            if let syncStateFileWrapper = subFileWrappers.values.filter({ $0.filename! == "syncState.json" }).first {
                if let data = syncStateFileWrapper.regularFileContents {
                    if let syncStateDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                        syncState = SyncState.from(dictionary: syncStateDictionary)
                    }
                }
            }

            if let identifiersFileWrapper = subFileWrappers.values.filter({ $0.filename! == "identifiers.json" }).first {
                if let data = identifiersFileWrapper.regularFileContents {
                    if let identifiersDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : [String] ] {
                        localIdentifierMapping = identifiersDictionary
                    }
                }
            }
            
            if let snapshotFileWrapper = subFileWrappers.values.filter({ $0.filename! == "snapshot.json" }).first {
                if let data = snapshotFileWrapper.regularFileContents {
                    if let snapshotDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                        snapshot = DeserializeDatabaseSnapshot(fromJsonDictionary: snapshotDictionary)
                    }
                }
            }
            
            if let historiesFileWrapper = subFileWrappers.values.filter({ $0.filename! == "histories.json" }).first {
                if let data = historiesFileWrapper.regularFileContents {
                    if let historiesDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                        histories = DeserializeJournalSet(fromJsonDictionary: historiesDictionary, diffsUseJournalIdentifier: true)
                    }
                }
            }
            
            if let journalsFileWrapper = subFileWrappers.values.filter({ $0.filename! == "journals.json" }).first {
                if let data = journalsFileWrapper.regularFileContents {
                    if let journalsDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                        journalCache = DeserializeJournalSet(fromJsonDictionary: journalsDictionary)
                    }
                }
            }
        }

        if let syncState = syncState, let snapshot = snapshot, let histories = histories, let journalCache = journalCache,
            var localIdentifierMapping = localIdentifierMapping {
            // Load our local identifier
            if let newLocalIdentifier = localIdentifierMapping[self.userIdentifier]?.last {
                localIdentifier = newLocalIdentifier
            } else {
                // No change to local identifier, but add it to the list
                if var localIdentifiersForUserId = localIdentifierMapping[self.userIdentifier] {
                    localIdentifiersForUserId.append(localIdentifier)
                    localIdentifierMapping[self.userIdentifier] = localIdentifiersForUserId
                } else {
                    localIdentifierMapping[self.userIdentifier] = [localIdentifier]
                }
            }
            self.localIdentifierMapping = localIdentifierMapping
            self.syncState = syncState
            
            let database = Database(localIdentifier: localIdentifier,
                                    cachedJournals: journalCache.journals,
                                    cachedObjects: snapshot.objects,
                                    cachedSingleEntityJournals: histories.journals)
            databaseController = SampleDatabaseController(database: database)
        }
    }
    
    func journals(fromFiles files: [URL]) -> [Journal] {
        let maybeJournals: [Journal?] = files.map({ file in
            var journal: Journal? = nil
            do {
                // Load journal file
                let data = try Data(contentsOf: file)
                if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                    if let identifier = jsonDictionary["_id"] as? String,
                        let jsonArray = jsonDictionary["df"] as? [ [String : Any] ] {
                        
                        let diffs: [JournalDiff] = jsonArray.map { DeserializeJournalDiff(fromJsonDictionary: $0)! }
                        journal = Journal(identifier: identifier, diffs: diffs)
                    }
                }
            } catch {
                // Failed
            }
            
            return journal
        })
        return maybeJournals.filter({ $0 != nil }) as! [Journal]
    }
}

// Person API
extension Document {
    var people: [Person] {
        let objects = databaseController.database.fetchObjects().sorted(by: { $0.creationDate < $1.creationDate })
        let people = objects.map { object in
            return Person(identifier: object.identifier,
                          name: object.properties[Person.namePropertyKey]!,
                          weight: Int(object.properties[Person.weightPropertyKey]!)!,
                          age: Int(object.properties[Person.agePropertyKey]!)!)
        }
        return people
    }
    
    func add(person: Person) {
        databaseController.add(person: person)
    }

    func modifyPerson(identifier: String, properties: DatabaseObjectPropertiesDictionary) {
        databaseController.modifyPerson(identifier: identifier, properties: properties)
    }
    
    private func removeFolder(folder: URL) {
        if FileManager.default.fileExists(atPath: folder.path) {
            try! FileManager.default.removeItem(at: folder)
        }
    }
    
    // Change the localIdentifier and save the previouis one to the cache
    func cycleLocalIdentifier() {
        // Generate a new local identifier
        let newLocalIdentifier = UUID().uuidString
        databaseController.database.localIdentifier = newLocalIdentifier
        self.localIdentifier = newLocalIdentifier

        var localIdentifiers = localIdentifierMapping[self.userIdentifier] ?? []
        localIdentifiers.append(newLocalIdentifier)
        
        localIdentifierMapping[self.userIdentifier] = localIdentifiers
        self.updateChangeCount(.changeDone)
    }
}

// Syncing API
extension Document {
    func sync(remoteFolderURL: URL) {
        let syncDelegate = FileSyncDelegate(localURL: self.localFolder, remoteURL: remoteFolderURL)
        
        DispatchQueue.global().async {
            // Write out all local journals that are newer than the remote or doesn't exist remotely yet
            var pushFiles: [URL] = []
            if let localIdentifiers = self.localIdentifierMapping[self.userIdentifier] {
                for localIdentifier in localIdentifiers {
                    if let localJournal = self.databaseController.database.journalCache.journals[localIdentifier] {
                        if localJournal.diffs.count > 0 {
                            
                            let currentLastDiffDate = localJournal.diffs.last!.timestamp
                            let localJournalFilename = "\(localIdentifier).journal"
                            var pushThisFile = false
                            
                            // If it's in the cache, take a look
                            if let info = self.syncState.journalFileMetadata[localIdentifier] {
                                if info.lastDiffDate < currentLastDiffDate {
                                    // What's in mem is newer than what we have in the cache, so
                                    pushThisFile = true
                                }
                            } else {
                                // It's not even in the cache, so definitely write it out and push it if necessary
                                pushThisFile = true
                            }
                            
                            if pushThisFile {
                                let journalFileURL = self.localFolder.appendingPathComponent(localJournalFilename)
                                
                                // Write the journal to disk
                                var jsonDictionary: [String : Any] = [:]
                                jsonDictionary["_id"] = localIdentifier
                                jsonDictionary["df"] = localJournal.diffs.map { SerializeJournalDiff(journalDiff: $0) }
                                let data = try! JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
                                try! data.write(to: journalFileURL)
                                
                                // Get the write date from the file system
                                let attributes = try! FileManager.default.attributesOfItem(atPath: journalFileURL.path)
                                let lastWriteDate = attributes[FileAttributeKey.modificationDate] as! Date
                                
                                // Save the latest info to the cache
                                self.syncState.journalFileMetadata[localIdentifier] = JournalFileMetadata(lastDiffDate: currentLastDiffDate, lastWriteDate: lastWriteDate)
                                
                                let fileMetadata = FileMetadata(filename: localJournalFilename, lastModifiedDate: lastWriteDate, filesize: data.count)
                                self.syncState.localMetadata[localJournalFilename] = fileMetadata
                                
                                pushFiles.append(journalFileURL)
                            }
                        }
                    }
                }
            }
            
            Sync(localMetadata: self.syncState.localMetadata, remoteMetadata: self.syncState.remoteMetadata, delegate: syncDelegate) { syncResult, error in
                if let error = error {
                    Swift.print("Failed to sync: \(error)")
                } else if let syncResult = syncResult {
                    var documentChanged = (syncResult.pushedFiles.count > 0 || syncResult.pulledFiles.count > 0)
                    
                    // Do the merge ...
                    let journalFilenames: [String] = syncResult.pulledFiles.filter { $0.hasSuffix(".journal") }
                    let journalFileURLs: [URL] = journalFilenames.map { self.localFolder.appendingPathComponent($0) }
                    
                    let remoteJournals = self.journals(fromFiles: journalFileURLs)
                    DispatchQueue.main.async {
                        let mergeChangedDatabase = self.databaseController.database.merge(multiplexJournals: remoteJournals)
                        documentChanged = documentChanged || mergeChangedDatabase
                        
                        if documentChanged {
                            self.syncState.remoteMetadata = syncResult.remoteMetadata
                            
                            if syncResult.pushedFiles.count > 0 {
                                Swift.print("Pushed \(syncResult.pushedFiles.count) file(s)")
                            }
                            if syncResult.pulledFiles.count > 0 {
                                Swift.print("Pulled \(syncResult.pulledFiles.count) file(s)")
                            }

                            self.updateChangeCount(.changeDone)
                        }
                    }
                } else {
                    fatalError()
                }
            }
        }
    }
}

