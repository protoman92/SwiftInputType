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

public extension InputIdentifierType {
    
    /// Check if the input identifier is equal to another identifier.
    ///
    /// - Parameter identifier: A String value.
    /// - Returns: A Bool value.
    public func hasIdentifier(_ identifier: String) -> Bool {
        return inputIdentifier == identifier
    }
}

/// Implement this protocol to deliver input content.
public protocol InputContentType: InputIdentifierType {
    /// Get the associated InputType.
    var inputModel: InputType { get }
    
    // This is the user' input String.
    var inputContent: String { get }
    
    /// Initialize with an InputType instance.
    ///
    /// - Parameter input: An InputType instance.
    init(`for` input: InputType)
}

public extension InputContentType {
    /// Check whether inputContent is empty.
    public var isEmpty: Bool {
        return inputContent.isEmpty
    }
    
    /// Check whether inputContent is not empty.
    public var isNotEmpty: Bool {
        return !isEmpty
    }
    
    /// Return identifier.
    public var inputIdentifier: String {
        return inputModel.identifier
    }
    
    /// Return isRequired.
    public var isRequired: Bool {
        return inputModel.isRequired
    }
}

/// Encompasses all InputData functionalities. Built on top of InputContentType
/// with additional reactive functionalities.
public protocol InputDataType: InputContentType {
    
    /// Override inputContent to provide setter.
    var inputContent: String { get set }
    
    /// Get an InputContentType Observable.
    var inputObservable: Observable<InputContentType> { get }
    
    /// Get an InputContentType Observer.
    var inputObserver: AnyObserver<InputContentType> { get }
}

/// Use this class to hold input information (such as the input identifier
/// and the current input). Objects of type InputData can be wrapped in a
/// RxSwift Variable to watch for content changes.
public final class InputData {
    
    /// Get the input identifier and isRequired flag from this.
    fileprivate let input: InputType
    
    // This is the user' input.
    fileprivate let content: Variable<String>
    
    /// When the inputContent changes, this listener will call onNext. Lazy
    /// properties that require self needs their types explicitly specified.
    /// Here a BehaviorSubject is used because we want to emit empty input
    /// as well. If we use a PublishSubject, the empty input will be omitted.
    fileprivate lazy var inputSubject: BehaviorSubject<InputContentType> =
        BehaviorSubject<InputContentType>(value: Input(input: self))
    
    /// Validate inputs when they are confirmed.
    fileprivate var validator: InputValidatorType?
    
    fileprivate let disposeBag: DisposeBag
    
    public init(`for` input: InputType) {
        self.input = input
        content = Variable("")
        disposeBag = DisposeBag()
        
        content.asObservable()
            .doOnNext({[weak self] in
                self?.contentChanged($0, with: self)
            })
            .subscribe()
            .addDisposableTo(disposeBag)
    }
    
    deinit {
//        debugPrint("Deinitialized \(self)")
    }
}

public extension InputData {
    
    /// Use this struct to deliver content, instead of the main InputData,
    /// since it may lead to a resource leak.
    fileprivate class Input {
        fileprivate let input: InputType
        fileprivate var content: String
        
        fileprivate required init(for input: InputType) {
            self.input = input
            content = ""
        }
        
        fileprivate convenience init(input: InputDataType) {
            self.init(for: input.inputModel)
            content = input.inputContent
        }
    }
}

extension InputData.Input: InputContentType {
    
    /// Get the associated InputType.
    var inputModel: InputType {
        return input
    }
    
    /// Return input content.
    public var inputContent: String {
        return content
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

extension InputData: InputDataType {
    
    /// Get the associated input.
    public var inputModel: InputType {
        return input
    }
    
    /// Return content.
    public var inputContent: String {
        get { return content.value }
        set { content.value = newValue }
    }
    
    /// Return inputSubject as an Observable.
    public var inputObservable: Observable<InputContentType> {
        return inputSubject.asObservable()
    }
    
    /// Return inputSubject as an Observer.
    public var inputObserver: AnyObserver<InputContentType> {
        return inputSubject.asObserver()
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
        return "id: \(inputIdentifier), Content: \(inputContent), Required: \(isRequired)"
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

extension InputData.Input: CustomStringConvertible {
    public var description: String {
        return "id: \(inputIdentifier), Content: \(inputContent), Required: \(isRequired)"
    }
}

public func ==(lhs: InputData, rhs: InputData) -> Bool {
    return lhs.inputIdentifier == rhs.inputIdentifier
}
