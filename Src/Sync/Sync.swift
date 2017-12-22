//
//  RefactoredSyncer.swift
//  SlouchNotesPocket
//
//  Created by Allen Ussher on 12/15/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public protocol SyncDelegate {
    func fetchRemoteMetadata(completion: @escaping ([String : FileMetadata]?, Error?) -> Void)
    
    func pull(files: [String], completion: @escaping (Error?) -> Void)
    
    func push(files: [String],  completion: @escaping (Error?) -> Void)
}

public typealias SyncResult = (pulledFiles: [String], pushedFiles: [String], remoteMetadata: [String : FileMetadata])

func ComputeFilesToPush(localMetadata: [String : FileMetadata], remoteMetadata: [String : FileMetadata]) -> [String] {
    // Figure out which files to push. The files to push are the ones that are newer locally.
    let filesToPush = localMetadata.values.filter({ localFileMetadata in
        if !localFileMetadata.filename.hasSuffix(".journal") {
            return false
        }
        
        if let remoteFileMetadata = remoteMetadata[localFileMetadata.filename] {
            // Push if local file is newer
            return localFileMetadata.lastModifiedDate > remoteFileMetadata.lastModifiedDate
        } else {
            // Remote file doesn't exist, so we want to push the local file
            return true
        }
    }).map { $0.filename }
    
    return filesToPush
}

func ComputeFilesToPull(remoteMetadata: [String : FileMetadata], fetchedRemoteMetadata: [String : FileMetadata],
                               localFiles: [String]) -> [String] {
    // Figure out which files to pull. Files to pull are the ones that are available remotely only or are newer remotely
    let filesToPull = fetchedRemoteMetadata.values.filter({ fetchedRemoteFileMetadata in
        if !fetchedRemoteFileMetadata.filename.hasSuffix(".journal") {
            return false
        }
        
        // Don't pull local files
        guard !localFiles.contains(fetchedRemoteFileMetadata.filename) else { return false }
        
        if let localFileMetadata = remoteMetadata[fetchedRemoteFileMetadata.filename] {
            // Pull if remote file is newer
            return fetchedRemoteFileMetadata.lastModifiedDate > localFileMetadata.lastModifiedDate
        } else {
            // Remote file is not available locally, so yes we want to pull the remote file.
            return true
        }
    }).map { $0.filename }
    
    return filesToPull
}

// Given local metadata, sync() will
// - fetch remote metadata
// - compare local metadata against remote metadata and fetch files that are newer
// - push files that are newer locally
//
// Interactions with remote and local files are handled by the delegate. This is simply the algorithm
// that determines what to push and pull.
public func Sync(localMetadata: [String : FileMetadata],
                 remoteMetadata: [String : FileMetadata],
                 delegate: SyncDelegate,
                 completion: @escaping (SyncResult?, Error?) -> Void) {
    delegate.fetchRemoteMetadata { fetchedRemoteMetadata, error in
        if let error = error {
            completion(nil, error)
            return
        }
        guard let fetchedRemoteMetadata = fetchedRemoteMetadata else {
            fatalError()
        }
        
        let localFiles: [String] = localMetadata.map { $0.value.filename }
        let filesToPush = ComputeFilesToPush(localMetadata: localMetadata, remoteMetadata: fetchedRemoteMetadata)
        let filesToPull = ComputeFilesToPull(remoteMetadata: remoteMetadata, fetchedRemoteMetadata: fetchedRemoteMetadata, localFiles: localFiles)
        
        let dispatchGroup = DispatchGroup()

        var pullError: Error? = nil
        dispatchGroup.enter()
        delegate.pull(files: filesToPull) { error in
            pullError = error
            
            dispatchGroup.leave()
        }

        var pushError: Error? = nil
        dispatchGroup.enter()
        delegate.push(files: filesToPush) { error in
            pushError = error
            
            dispatchGroup.leave()
        }

        dispatchGroup.wait()
        
        if pullError != nil {
            completion(nil, pullError)
        } else if pushError != nil {
            completion(nil, pushError)
        } else  {
            var updatedRemoteMetadata = remoteMetadata
            for fileToPull in filesToPull {
                updatedRemoteMetadata[fileToPull] = fetchedRemoteMetadata[fileToPull]
            }

            let syncResult = SyncResult(pulledFiles: filesToPull,
                                        pushedFiles: filesToPush,
                                        remoteMetadata: updatedRemoteMetadata)
            
            completion(syncResult, nil)
        }
    }
}
