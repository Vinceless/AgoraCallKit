//
//  CallType.swift
//  CallCore
//
//  Created by Vince on 2021/3/29.
//

import Foundation

public enum CallType: String {
    case audio
    case video
    
    public var description: String { rawValue }
}
