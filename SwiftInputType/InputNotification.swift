//
//  InputNotification.swift
//  SwiftUtilities
//
//  Created by Hai Pham on 4/23/17.
//  Copyright © 2017 Swiften. All rights reserved.
//

/// Implement this protocol to notify observers of inputs or errors.
public protocol InputNotificationType {
    /// Whether there are input errors.
    var hasErrors: Bool { get }
    
    /// Return either inputs or errors, depending on whether errors are
    /// present.
    var outputs: [String: String] { get }
    
    /// Append an input.
    ///
    /// - Parameters:
    ///   - input: A String value.
    ///   - key: A String value.
    mutating func append(input: String, for key: String)
    
    /// Append an error.
    ///
    /// - Parameters:
    ///   - input: A String value.
    ///   - key: A String value.
    mutating func append(error: String, for key: String)
    
    /// Construct from an Array of InputNotificationComponentType.
    init(from components: [InputNotificationComponentType])
}

/// Implement this protocol to hold notification component for one input.
public protocol InputNotificationComponentType {
    
    /// Whether there is an input error.
    var hasError: Bool { get }
    
    /// The input's identifier.
    var inputKey: String { get }
    
    /// The input value. Depending on whether hasError is true/false, this
    /// can either be an input content or error message.
    var inputValue: String { get }
}

public extension InputData {
    
    /// Use this class to aggregate inputs/errors and notify observers.
    struct Notification {
        
        /// All entered inputs.
        var inputs: [String: String]
        
        /// All input errors.
        var errors: [String: String]
        
        init() {
            inputs = [:]
            errors = [:]
        }
        
        /// Use this class to construct a Notification. We do not need a
        /// Builder for this struct since it is set to fileprivate.
        struct Component {
            
            /// The input's identifier.
            var key = ""
            
            /// The input content.
            var value = ""
            
            /// The error message.
            var error = ""
        }
    }
}

extension InputData.Notification: InputNotificationType {
    
    /// Detect if there are input errors.
    public var hasErrors: Bool {
        return errors.isNotEmpty
    }
    
    /// Return either inputs or errors, depending on whether errors are
    /// present.
    public var outputs: [String: String] {
        return hasErrors ? errors : inputs
    }
    
    /// Append an input.
    ///
    /// - Parameters:
    ///   - input: A String value.
    ///   - key: A String value. This should be the input identifier.
    public mutating func append(input: String, for key: String) {
        inputs.updateValue(input, forKey: key)
    }
    
    /// Append an error.
    ///
    /// - Parameters:
    ///   - error: A String value.
    ///   - key: A String value. This should be the input identifier.
    public mutating func append(error: String, for key: String) {
        errors.updateValue(error, forKey: key)
    }
    
    public init(from components: [InputNotificationComponentType]) {
        self.init()
        
        for component in components {
            let key = component.inputKey
            let value = component.inputValue
            
            if component.hasError {
                append(error: value, for: key)
            } else {
                append(input: value, for: key)
            }
        }
    }
}

extension InputData.Notification: CustomStringConvertible {
    public var description: String {
        return "hasErrors: \(hasErrors), output: \(outputs)"
    }
}

extension InputData.Notification.Component: InputNotificationComponentType {
    
    /// Detect if there is an input error.
    public var hasError: Bool {
        return error.isNotEmpty
    }
    
    /// The input's identifier.
    public var inputKey: String {
        return key
    }
    
    /// Either the input content, or an error message.
    public var inputValue: String {
        return hasError ? error : value
    }
}
