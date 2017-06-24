//
//  InputNotification.swift
//  SwiftUtilities
//
//  Created by Hai Pham on 4/23/17.
//  Copyright © 2017 Swiften. All rights reserved.
//

/// Implement this protocol to hold notification component for one input.
public protocol InputNotificationComponentType {
    
    /// Whether there is an input error.
    var hasError: Bool { get }
    
    /// The input identifier.
    var inputKey: String { get }
    
    /// The input value.
    var inputValue: String { get }
    
    /// The input error
    var inputError: String { get }
}

/// Implement this protocol to notify observers of inputs or errors.
public protocol InputNotificationType {
    /// Whether there are input errors.
    var hasErrors: Bool { get }
    
    /// The input components that contain the input/error from validation.
    var allComponents: [InputNotificationComponentType] { get }
    
    /// Append an InputNotificationComponentType.
    ///
    /// - Parameter component: An InputNotificationComponentType instance.
    mutating func append(component: InputNotificationComponentType)
    
    /// Construct from an Array of InputNotificationComponentType.
    init(from components: [InputNotificationComponentType])
}

public extension InputNotificationType {
    
    /// Get all valid InputNotificationComponentType.
    public var validComponents: [InputNotificationComponentType] {
        return allComponents.filter({!$0.hasError})
    }
    
    /// Get all error InputNotificationComponentType.
    public var errorComponents: [InputNotificationComponentType] {
        return allComponents.filter({$0.hasError})
    }
    
    /// Check if there is at least one component with a specific error message.
    ///
    /// - Parameter error: A String value.
    /// - Returns: A Bool value.
    public func hasError(_ error: String) -> Bool {
        return allComponents.any(satisfying: {$0.inputError == error})
    }
}

/// Use this class to aggregate inputs/errors and notify observers.
public struct InputNotification {
    
    /// All InputNotificationComponentType.
    var components: [InputNotificationComponentType]
    
    init() {
        components = []
    }
    
    /// Use this class to construct a Notification.
    public struct Component {
        
        /// The input's identifier.
        var key = ""
        
        /// The input content.
        var value = ""
        
        /// The error message.
        var error = ""
    }
}

public extension InputNotification.Component {
    
    /// Builder class for InputNotification.Component.
    public final class Builder {
        private var component: InputNotification.Component
        
        init() {
            component = InputNotification.Component()
        }
        
        /// Set the component key identifier.
        ///
        /// - Parameter key: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(key: String) -> Builder {
            component.key = key
            return self
        }
        
        /// Set the component key identifier.
        ///
        /// - Parameter provider: An InputIdentifierType instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(keyProvider provider: InputIdentifierType) -> Builder {
            return with(key: provider.inputIdentifier)
        }
        
        /// Set the component value.
        ///
        /// - Parameter value: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(value: String) -> Builder {
            component.value = value
            return self
        }
        
        /// Set the component value.
        ///
        /// - Parameter value: An InputContentType instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(valueProvider provider: InputContentType) -> Builder {
            return with(value: provider.inputContent)
        }
        
        /// Set the component error.
        ///
        /// - Parameter error: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(error: String) -> Builder {
            component.error = error
            return self
        }
        
        /// Get component.
        ///
        /// - Returns: InputNotification.Component instance.
        public func build() -> InputNotificationComponentType {
            return component
        }
    }
}

public extension InputNotification {
    
    /// Get an InputNotificationComponent.Builder instance.
    ///
    /// - Returns: An InputNotificationComponent.Builder instance.
    public static func componentBuilder() -> Component.Builder {
        return Component.Builder()
    }
}

extension InputNotification.Component: InputNotificationComponentType {
    
    /// Detect if there is an input error.
    public var hasError: Bool {
        return error.isNotEmpty
    }
    
    /// The input identifier.
    public var inputKey: String {
        return key
    }
    
    /// The input value.
    public var inputValue: String {
        return value
    }
    
    /// The input error.
    public var inputError: String {
        return error
    }
}

extension InputNotification: InputNotificationType {
    
    /// Check whether there are errors
    public var hasErrors: Bool {
        return components.filter({$0.hasError}).isNotEmpty
    }

    /// Get components.
    public var allComponents: [InputNotificationComponentType] {
        return components
    }
    
    /// Append an InputNotificationComponentType.
    ///
    /// - Parameter component: An InputNotificationComponentType instance.
    public mutating func append(component: InputNotificationComponentType) {
        components.append(component)
    }
    
    public init(from components: [InputNotificationComponentType]) {
        self.init()
        self.components.append(contentsOf: components)
    }
}

extension InputNotification.Component: CustomStringConvertible {
    public var description: String {
        return "hasErrors: \(hasError), value: \(value), error: \(error)"
    }
}

extension InputNotification: CustomStringConvertible {
    public var description: String {
        return "hasErrors: \(hasErrors), components: \(components)"
    }
}
