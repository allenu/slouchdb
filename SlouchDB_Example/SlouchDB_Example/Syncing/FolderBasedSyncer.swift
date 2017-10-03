//
//  FolderBasedSyncer.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/21/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

class FolderBasedRemoteFileManager: RemoteFileManager {
    let remoteURL: URL
    
    init(remoteURL: URL) {
        self.remoteURL = remoteURL
    }
    
    func fetchFileMetadata(completion: ([FileMetadata], Error?) -> Void) {
        let resourceKeys : [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        var result: [FileMetadata] = []

        let fileEnumerator = FileManager.default.enumerator(at: remoteURL, includingPropertiesForKeys: nil)
        while let element = fileEnumerator?.nextObject() {
            if let fileURL = element as? URL {
                if fileURL.isFileURL {
                    let resourceValues = try! fileURL.resourceValues(forKeys: Set(resourceKeys))
                    if let filesize = resourceValues.fileSize,
                        let lastModifiedDate = resourceValues.contentModificationDate {
                        let filename = fileURL.lastPathComponent
                        
                        let fileMetadata = FileMetadata(filename: filename, lastModifiedDate: lastModifiedDate, filesize: filesize)
                        result.append(fileMetadata)
                    }
                }
            }
        }
        
        completion(result, nil)
    }
    
    func fetch(filename: String, localURL: URL, completion: (Error?) -> Void) {
        let remoteFile: URL = remoteURL.appendingPathComponent(filename)
        
        do {
            // Remove old local file
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            // Overwrite it
            try FileManager.default.copyItem(at: remoteFile, to: localURL)
        } catch {
            print("Encountered error: \(error)")
        }
        completion(nil)
    }
    
    func send(file: URL,  completion: (Error?) -> Void) {
        let filename = file.lastPathComponent
        let remoteFileURL = remoteURL.appendingPathComponent(filename)
        
        // Remove remote file
        if FileManager.default.fileExists(atPath: remoteFileURL.path) {
            try! FileManager.default.removeItem(at: remoteFileURL)
        }
        // Overwrite it
        try! FileManager.default.copyItem(at: file, to: remoteFileURL)
        
        completion(nil)
    }
}

typealias PullResult = (pulledSyncMetadata: [String : FileMetadata], pulledFiles: [URL])

// Returns folder metadata for JUST the updated files that were copied.
func Pull(remoteFolderURL: URL, localFolder: URL, localSyncMetadata: [String : FileMetadata], remoteFileManager: RemoteFileManager, completion: (PullResult) -> Void)  {
    
    remoteFileManager.fetchFileMetadata { fileMetadata, error in
        
        var pulledSyncMetadata: [String : FileMetadata] = [:]
        var pulledFiles: [URL] = []
        let serialQueue = DispatchQueue(label: "com.ussherpress.SlouchDB.RemoteFileManager")

        var copyFiles = false
        
        let dispatchGroup = DispatchGroup()
        
        for singleFileMetadata in fileMetadata {
            if let cachedFileMetadata = localSyncMetadata[singleFileMetadata.filename] {
                if cachedFileMetadata.filesize != singleFileMetadata.filesize || cachedFileMetadata.lastModifiedDate != singleFileMetadata.lastModifiedDate {
                    copyFiles = true
                }
            } else {
                copyFiles = true
            }
            
            if copyFiles {
                let localFileURL = localFolder.appendingPathComponent(singleFileMetadata.filename)
                
                dispatchGroup.enter()
                
                remoteFileManager.fetch(filename: singleFileMetadata.filename, localURL: localFileURL, completion: { error in
                    if error == nil {
                        serialQueue.async {
                            pulledFiles.append(localFileURL)
                            pulledSyncMetadata[singleFileMetadata.filename] = FileMetadata(filename: singleFileMetadata.filename, lastModifiedDate: singleFileMetadata.lastModifiedDate, filesize: singleFileMetadata.filesize)
                            dispatchGroup.leave()
                        }
                    } else {
                        // Error!
                        dispatchGroup.leave()
                    }
                })
            }
        }
        
        dispatchGroup.wait()
        
        let result = PullResult(pulledSyncMetadata: pulledSyncMetadata, pulledFiles: pulledFiles)
        completion(result)
    }
}

func Push(files: [URL], toRemoteFolder remoteFolder: URL, remoteFileManager: RemoteFileManager, completion: (Error?) -> Void) {
    let dispatchGroup = DispatchGroup()

    for file in files {
        dispatchGroup.enter()
        remoteFileManager.send(file: file) { error in
            dispatchGroup.leave()
        }
    }
    
    dispatchGroup.wait()
    completion(nil)
}

typealias SyncResult = (pulledSyncMetadata: [String : FileMetadata], pulledFiles: [URL], pushedSyncMetadata: [String : FileMetadata], updatedSyncMetadata: [String : FileMetadata])

//
// Given a list of local files and remote folder, this will synchronize the two by:
// 1. Inspect the remote folder and comparing the filesize and lastModifiedDates of the files against
//    the entries in syncMetadata. If the remote file is newer or of a different size, the file will
//    be copied to the local folder.
// 2. Inspect the remote folder and if the local files are newer or of a different size, copy the
//    files to the remote folder.
// 3. On return, SyncResult will contain a list of the files copied to the local folder and the
//    the metadata for each file copied. If no files were pulled, both of these will be empty.
//
func Sync(syncMetadata: [String : FileMetadata], localFiles: [URL], remoteFolder: URL, localFolder: URL, remoteFileManager: RemoteFileManager, completion: (SyncResult) -> Void) {
    Pull(remoteFolderURL: remoteFolder, localFolder: localFolder, localSyncMetadata: syncMetadata, remoteFileManager: remoteFileManager) { pullResult in

        let syncMetadataWithPulls = syncMetadata.merging(pullResult.pulledSyncMetadata, uniquingKeysWith: { _, new in new })
        
        // Get metadata for each local file
        let urlAndMetadataForLocalFiles: [(URL, FileMetadata)] = localFiles.map({ localFile in
            let attributes = try! FileManager.default.attributesOfItem(atPath: localFile.path)
            let urlAndMetadata = (localFile, FileMetadata(filename: localFile.lastPathComponent, lastModifiedDate: attributes[FileAttributeKey.modificationDate] as! Date, filesize: attributes[FileAttributeKey.size] as! Int))
            
            return urlAndMetadata
        })
        
        let urlAndMetadataToPush = urlAndMetadataForLocalFiles.filter( { urlAndMetadata in
            let filename = urlAndMetadata.1.filename
            if let metadata = syncMetadataWithPulls[filename] {
                if metadata.filesize != urlAndMetadata.1.filesize || urlAndMetadata.1.lastModifiedDate > metadata.lastModifiedDate {
                    // Local file is newer or of a different size
                    return true
                } else {
                    return false
                }
            } else {
                // Sync doesn't know about this file yet, so definitely push it
                return true
            }
        })
        let filesToPush = urlAndMetadataToPush.map { $0.0 }
        
        Push(files: filesToPush, toRemoteFolder: remoteFolder, remoteFileManager: remoteFileManager) { error in
            var pushedSyncMetadata: [String : FileMetadata] = [:]
            if error == nil {
                // Update our local metadata
                for urlAndMetadata in urlAndMetadataToPush {
                    pushedSyncMetadata[urlAndMetadata.1.filename] = urlAndMetadata.1
                }
            }
            
            let syncMetadataWithPullsAndPushes = syncMetadataWithPulls.merging(pushedSyncMetadata, uniquingKeysWith: { _, new in new })
            let syncResult = SyncResult(pulledSyncMetadata: pullResult.pulledSyncMetadata, pulledFiles: pullResult.pulledFiles, pushedSyncMetadata: pushedSyncMetadata, updatedSyncMetadata: syncMetadataWithPullsAndPushes)
            
            completion(syncResult)
        }
    }
}
