//
//  PeopleAppTests.swift
//  PeopleAppTests
//
//  Created by Allen Ussher on 12/5/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import XCTest
@testable import PeopleApp

class SlouchDB_ExampleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testPull() {
        let remoteFolderURL = URL(fileURLWithPath: "/Users/allenu/tmp/test/remote")
        let localFolderURL = URL(fileURLWithPath: "/Users/allenu/tmp/test/local")
        let localSyncMetadata: [String : FileMetadata] = [:]
        let remoteFileManager = FolderBasedRemoteFileManager(remoteURL: remoteFolderURL)
        Pull(remoteFolderURL: remoteFolderURL, localFolder: localFolderURL, localSyncMetadata: localSyncMetadata, remoteFileManager: remoteFileManager) { result in
            
            print(result)
        }
    }
    
    func testPush() {
        let srcFolderURL = URL(fileURLWithPath: "/Users/allenu/tmp/test/remote")
        var files: [URL] = []
        let fileEnumerator = FileManager.default.enumerator(at: srcFolderURL, includingPropertiesForKeys: nil)
        while let element = fileEnumerator?.nextObject() {
            if let fileURL = element as? URL {
                if fileURL.isFileURL {
                    files.append(fileURL)
                }
            }
        }
        
        let tmpDirectoryURL = FileManager.default.temporaryDirectory
        let remoteFileManager = FolderBasedRemoteFileManager(remoteURL: tmpDirectoryURL)
        Push(files: files, toRemoteFolder: tmpDirectoryURL, remoteFileManager: remoteFileManager) { error in
            
        }
    }
    
    func testSerializeSyncMetadata() {
        let syncMetadata: [String : FileMetadata] = [
            "file1.txt" : FileMetadata(filename: "file1.txt", lastModifiedDate: Date(), filesize: 1234),
            "file2.txt" : FileMetadata(filename: "file2.txt", lastModifiedDate: Date(), filesize: 994943),
            "file3.txt" : FileMetadata(filename: "file3.txt", lastModifiedDate: Date(timeIntervalSince1970: 0), filesize: 11111),
            ]
        _ = FileManager.default.temporaryDirectory.appendingPathComponent("metadata.json")
        _ = SerializeSyncMetadata(syncMetadata: syncMetadata)
    }
    
}

