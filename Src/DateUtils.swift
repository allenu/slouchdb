//
//  DateUtils.swift
//  SlouchDB
//
//  Created by Allen Ussher on 10/8/17.
//  Copyright © 2017 Ussher Press. All rights reserved.
//

import Foundation

func StandardDateFormatter() -> DateFormatter {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    return dateFormatter
}

public func StringFromDate(_ date: Date) -> String {
    let dateFormatter = StandardDateFormatter()
    return dateFormatter.string(from: date)
}

public func DateFromString(_ string: String) -> Date? {
    let dateFormatter = StandardDateFormatter()
    return dateFormatter.date(from: string)
}
