//
//  FileSyncDelegate.swift
//  PeopleApp
//
//  Created by Allen Ussher on 12/22/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation
import SlouchDB

class FileSyncDelegate {
    let localURL: URL
    let remoteURL: URL

    init(localURL: URL, remoteURL: URL) {
        self.localURL = localURL
        self.remoteURL = remoteURL
    }
}

extension FileSyncDelegate: SyncDelegate {
    func fetchRemoteMetadata(completion: @escaping ([String : FileMetadata]?, Error?) -> Void) {
        let resourceKeys : [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        var result: [String : FileMetadata] = [:]
        
        let fileEnumerator = FileManager.default.enumerator(at: remoteURL, includingPropertiesForKeys: nil)
        while let element = fileEnumerator?.nextObject() {
            if let fileURL = element as? URL {
                if fileURL.isFileURL {
                    let resourceValues = try! fileURL.resourceValues(forKeys: Set(resourceKeys))
                    if let filesize = resourceValues.fileSize,
                        let lastModifiedDate = resourceValues.contentModificationDate {
                        let filename = fileURL.lastPathComponent
                        
                        let fileMetadata = FileMetadata(filename: filename, lastModifiedDate: lastModifiedDate, filesize: filesize)
                        result[filename] = fileMetadata
                    }
                }
            }
        }
        
        completion(result, nil)
    }
    
    func pull(files: [String], completion: @escaping (Error?) -> Void) {
        for filename in files {
            let localFileURL = localURL.appendingPathComponent(filename)
            let remoteFile: URL = remoteURL.appendingPathComponent(filename)
            
            do {
                // Remove old local file
                if FileManager.default.fileExists(atPath: localFileURL.path) {
                    try FileManager.default.removeItem(at: localFileURL)
                }
                // Overwrite it
                try FileManager.default.copyItem(at: remoteFile, to: localFileURL)
            } catch {
                print("Encountered error: \(error)")
            }
        }
        
        completion(nil)
    }
    
    func push(files: [String],  completion: @escaping (Error?) -> Void) {
        for filename in files {
            let localFileURL = localURL.appendingPathComponent(filename)
            let remoteFileURL = remoteURL.appendingPathComponent(filename)
            
            // Remove remote file
            if FileManager.default.fileExists(atPath: remoteFileURL.path) {
                try! FileManager.default.removeItem(at: remoteFileURL)
            }
            // Overwrite it
            try! FileManager.default.copyItem(at: localFileURL, to: remoteFileURL)
        }
        
        completion(nil)
    }
}
