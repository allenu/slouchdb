//
//  JournalFileMetadata.swift
//  SlouchNotes
//
//  Created by Allen Ussher on 12/22/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

public struct JournalFileMetadata {
    public let lastDiffDate: Date
    public let lastWriteDate: Date
    
    public init(lastDiffDate: Date, lastWriteDate: Date) {
        self.lastDiffDate = lastDiffDate
        self.lastWriteDate = lastWriteDate
    }
}

extension JournalFileMetadata {
    public func toDictionary() -> [String : Any] {
        var dict: [String : String] = [:]
        dict["lastDiffDate"] = StringFromDate(lastDiffDate)
        dict["lastWriteDate"] = StringFromDate(lastWriteDate)
        return dict
    }
    
    public static func from(dictionary: [String : Any]) -> JournalFileMetadata? {
        guard let lastDiffDateString = dictionary["lastDiffDate"] as? String else { return nil }
        guard let lastWriteDateString = dictionary["lastWriteDate"] as? String else { return nil }
        
        if let lastDiffDate = DateFromString(lastDiffDateString),
            let lastWriteDate = DateFromString(lastWriteDateString) {
            return JournalFileMetadata(lastDiffDate: lastDiffDate, lastWriteDate: lastWriteDate)
        }
        return nil
    }
}
