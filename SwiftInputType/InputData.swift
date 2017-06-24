//
//  InputData.swift
//  SwiftUtilities
//
//  Created by Hai Pham on 7/26/16.
//  Copyright © 2016 Swiften. All rights reserved.
//

import SwiftUtilities
import RxSwift

/// Implement this protocol to provide input identifier.
public protocol InputIdentifierType {
    // This should be a enum string value so that later we can perform input
    // validation easily.
    var inputIdentifier: String { get }
}

/// Implement this protocol to deliver input content.
public protocol InputContentType {
    // This is the user' input String.
    var inputContent: String { get }
    
    /// Check whether the input is required.
    var isRequired: Bool { get }
    
    /// Check if input content is empty.
    var isEmpty: Bool { get }
}

/// Encompasses all InputData functionalities. Built on top of 
/// InputContentType.
public protocol InputDataType: InputIdentifierType, InputContentType {
    
    /// Get the associated InputType.
    var inputModel: InputType? { get }
    
    /// Override inputContent to provide setter.
    var inputContent: String { get set }
    
    /// Get an InputDataType Observable.
    var inputObservable: Observable<InputContentType> { get }
    
    /// Get an InputDataType Observer.
    var inputObserver: AnyObserver<InputContentType> { get }
}

/// Use this class to hold input information (such as the input identifier
/// and the current input). Objects of type InputData can be wrapped in a
/// RxSwift Variable to watch for content changes.
public class InputData {
    
    /// Get the input identifier and isRequired flag from this.
    fileprivate var input: InputType?
    
    // This is the user' input.
    fileprivate let content: Variable<String>
    
    /// When the inputContent changes, this listener will call onNext. Lazy
    /// properties that require self needs their types explicitly specified.
    /// Here a BehaviorSubject is used because we want to emit empty input
    /// as well. If we use a PublishSubject, the empty input will be omitted.
    fileprivate lazy var inputSubject: BehaviorSubject<InputContentType> =
        BehaviorSubject<InputContentType>(value: Input.empty)
    
    /// Validate inputs when they are confirmed.
    fileprivate var validator: InputValidatorType?
    
    fileprivate let disposeBag: DisposeBag
    
    fileprivate init() {
        content = Variable("")
        disposeBag = DisposeBag()
        
        content.asObservable()
            .doOnNext({[weak self] in
                self?.contentChanged($0, with: self)
            })
            .subscribe()
            .addDisposableTo(disposeBag)
    }
}

public extension InputData {
    
    /// Return a Builder instance.
    ///
    /// - Returns: A Builder instance.
    public static func builder() -> Builder {
        return Builder()
    }
    
    /// Buider class for InputData.
    public struct Builder {
        fileprivate let inputData: InputData
        
        fileprivate init() {
            inputData = InputData()
        }
        
        /// Set the inputData's input.
        ///
        /// - Parameter input: An InputType instance.
        /// - Returns: The current Builder instance.
        public func with(input: InputType) -> Builder {
            inputData.input = input
            return self
        }
        
        /// Return inputData.
        ///
        /// - Returns: An InputData instance.
        public func build() -> InputData {
            return inputData
        }
    }
}

public extension InputData {
    
    /// Use this struct to deliver content, instead of the main InputData,
    /// since it may lead to a resource leak.
    fileprivate struct Input {
        fileprivate var identifier: String
        fileprivate var content: String
        fileprivate var required: Bool
        
        fileprivate init() {
            identifier = ""
            content = ""
            required = false
        }
        
        fileprivate init(input: InputDataType) {
            self.identifier = input.inputIdentifier
            self.content = input.inputContent
            self.required = input.isRequired
        }
    }
}

extension InputData.Input: InputContentType {
    
    /// Return identifier.
    public var inputIdentifier: String {
        return identifier
    }
    
    /// Return input content.
    public var inputContent: String {
        return content
    }
    
    /// Return required.
    public var isRequired: Bool {
        return required
    }
    
    /// Check whether inputContent is empty.
    public var isEmpty: Bool {
        return inputContent.isEmpty
    }
}

fileprivate extension InputData.Input {
    
    /// Use this for when we don't want to pass any content.
    fileprivate static var empty: InputData.Input {
        return InputData.Input()
    }
}

fileprivate extension InputData {
    
    /// This method is called when the inputContent changes.
    ///
    /// - Parameter content: A String value.
    fileprivate func contentChanged(_ str: String, with current: InputData?) {
        if let current = current {
            let input = Input(input: current)
            current.inputObserver.onNext(input)
        }
    }
}

extension InputData: ObservableConvertibleType {
    public typealias E = String
    
    /// Return an Observable that emits changes to this InputData.
    ///
    /// - Returns: An Observable instance.
    public func asObservable() -> Observable<String> {
        return content.asObservable()
    }
}

extension InputData: InputDataType {
    
    /// Get the associated input.
    public var inputModel: InputType? {
        return input
    }
    
    /// Return identifier.
    public var inputIdentifier: String {
        guard let input = self.input else {
            debugException()
            return ""
        }
        
        return input.identifier
    }
    
    /// Return isRequired.
    public var isRequired: Bool {
        guard let input = self.input else {
            debugException()
            return false
        }
        
        return input.isRequired
    }
    
    /// Return content.
    public var inputContent: String {
        get { return content.value }
        set { content.value = newValue }
    }
    
    /// Return validator.
    public var inputValidator: InputValidatorType? {
        return validator
    }
    
    /// Return inputSubject as an Observable.
    public var inputObservable: Observable<InputContentType> {
        return inputSubject.asObservable()
    }
    
    /// Return inputSubject as an Observer.
    public var inputObserver: AnyObserver<InputContentType> {
        return inputSubject.asObserver()
    }
    
    /// Check whether the input is empty.
    public var isEmpty: Bool {
        return inputContent.isEmpty
    }
}

public extension Sequence where Iterator.Element == InputData {}

extension InputData: Hashable {
    public var hashValue: Int {
        return inputIdentifier.hashValue
    }
}

extension InputData: Equatable {}

extension InputData: CustomStringConvertible {
    public var description: String {
        return "Content: \(inputContent), Required: \(isRequired)"
    }
}

extension InputData: CustomComparisonType {
    public func equals(object: InputData?) -> Bool {
        if let object = object {
            return object == self
        }
        
        return false
    }
}

public func ==(lhs: InputData, rhs: InputData) -> Bool {
    return lhs.inputIdentifier == rhs.inputIdentifier
}
