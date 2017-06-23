//
//  InputDetailType.swift
//  SwiftUtilities
//
//  Created by Hai Pham on 4/20/17.
//  Copyright © 2017 Swiften. All rights reserved.
//

import UIKit

/// Implement this protocol to provide input instances. Usually we can use
/// an enum for this purpose. Each instance shall provide the necessary
/// information for an input.
public protocol InputDetailType {
    
    /// The input's identifier.
    var identifier: String { get }
    
    /// Whether the input is required.
    var isRequired: Bool { get }
}
