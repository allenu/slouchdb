//
//  RemoteFileManager.swift
//  SlouchDB_Example
//
//  Created by Allen Ussher on 11/28/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

protocol RemoteFileManager {
    func fetchFileMetadata(completion: ([FileMetadata], Error?) -> Void)
    func fetch(filename: String, localURL: URL, completion: (Error?) -> Void)
    func send(file: URL,  completion: (Error?) -> Void)
}
