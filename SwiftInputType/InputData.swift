//
//  InputData.swift
//  SwiftUtilities
//
//  Created by Hai Pham on 7/26/16.
//  Copyright © 2016 Swiften. All rights reserved.
//

import SwiftUtilities
import RxSwift

/// Implement this protocol to provide validation.
public protocol InputValidatorType {
    
    /// Validate an input against a Sequence of inputs. Throw an Error if
    /// validation fails.
    ///
    /// - Parameters:
    ///   - input: The InputData to be validated.
    ///   - inputs: A Sequence of InputData to validate against.
    /// - Throws: An Error if validation fails.
    func validate<S: Sequence>(input: InputDataType, against inputs: S) throws
        where S.Iterator.Element: InputDataType
}

/// Implement this protocol to deliver input content.
public protocol InputContentType {
    // This should be a enum string value so that later we can perform input
    // validation easily.
    var inputIdentifier: String { get }
    
    // This is the user' input.
    var inputContent: String { get }
    
    /// Check whether the input is required.
    var isRequired: Bool { get }
    
    /// Check if input content is empty.
    var isEmpty: Bool { get }
}

/// Encompasses all InputData functionalities. Built on top of 
/// InputContentType.
public protocol InputDataType: InputContentType {
    
    /// Get a validator instance to validate the input.
    var inputValidator: InputValidatorType? { get }
    
    /// Override inputContent to provide setter.
    var inputContent: String { get set }
    
    /// Create a new InputNotificationType instance.
    ///
    /// - Parameters:
    ///   - components: An Array of InputNotificationComponentType.
    /// - Returns: An InputNotificationType instance.
    static func notification(from components: [InputNotificationComponentType])
        -> InputNotificationType
    
    /// Get an InputDataType Observable.
    var inputDataObservable: Observable<InputContentType> { get }
    
    /// Get an InputDataType Observer.
    var inputDataObserver: AnyObserver<InputContentType> { get }
    
    /// Produce a notification component based on existing input.
    ///
    /// - Parameter inputs: A Sequence of InputDataType to validate against.
    /// - Returns: An InputNotificationComponentType instance.
    func notificationComponent<S: Sequence>(validatingAgainst inputs: S)
        -> InputNotificationComponentType
        where S.Iterator.Element: InputDataType
}

/// Use this class to hold input information (such as the input identifier
/// and the current input). Objects of type InputData can be wrapped in a
/// RxSwift Variable to watch for content changes.
public class InputData {
    
    /// Get the input identifier and isRequired flag from this.
    fileprivate var inputDetail: InputDetailType?
    
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
    
    /// This can either be set, or initialized.
    fileprivate var disposeBag: DisposeBag?
    
    fileprivate init() {
        content = Variable("")
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
        public func with(input: InputDetailType) -> Builder {
            inputData.inputDetail = input
            return self
        }
        
        /// Set the inputData's disposeBag.
        ///
        /// - Parameter disposeBag: A DisposeBag instance.
        /// - Returns: The current Builder instance.
        public func with(disposeBag: DisposeBag) -> Builder {
            inputData.disposeBag = disposeBag
            return self
        }
        
        /// Set the inputData's inputValidator.
        ///
        /// - Parameter inputValidator: An InputValidatorType instance.
        /// - Returns: The current Builder instance.
        public func with(inputValidator: InputValidatorType) -> Builder {
            inputData.validator = inputValidator
            return self
        }
        
        /// Set inputDetailType and inputValidator at the same time. We can
        /// do this for enums that implement both these protocols.
        ///
        /// - Parameter composite: An I instance.
        /// - Returns: The current Builder instance.
        public func with<I: InputDetailType & InputValidatorType>(composite: I)
            -> Builder
        {
            return with(input: composite).with(inputValidator: composite)
        }
        
        /// Return inputData.
        ///
        /// - Returns: An InputData instance.
        public func build() -> InputData {
            inputData.onInstanceBuilt()
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
        
        /// We are not using Builder for this struct since we don't expect
        /// the init method to accept more than these 3 arguments, and it is
        /// set to fileprivate access.
        ///
        /// - Parameters:
        ///   - identifier: A String value.
        ///   - content: A String value.
        ///   - required: A Bool value.
        fileprivate init(identifier: String, content: String, required: Bool) {
            self.identifier = identifier
            self.content = content
            self.required = required
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
    
    /// This method is called when Builder.build() is called.
    fileprivate func onInstanceBuilt() {
        // If no DisposeBag is provided, initialize a new one.
        let disposeBag = self.disposeBag ?? DisposeBag()
        self.disposeBag = disposeBag
        
        content.asObservable()
            .doOnNext({[weak self] in self?.contentChanged($0, with: self)})
            .subscribe()
            .addDisposableTo(disposeBag)
    }
    
    /// This method is called when the inputContent changes.
    ///
    /// - Parameter content: A String value.
    fileprivate func contentChanged(_ str: String, with current: InputData?) {
        if let current = current {
            let input = Input(identifier: current.inputIdentifier,
                              content: current.inputContent,
                              required: current.isRequired)
            
            current.inputDataObserver.onNext(input)
        }
    }
}

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

extension InputData: ObservableConvertibleType {
    public typealias E = String
    
    /// Return an Observable that emits changes to this InputData.
    ///
    /// - Returns: An Observable instance.
    public func asObservable() -> Observable<String> {
        return content.asObservable()
    }
}

extension InputData: ObserverType {
    public func on(_ event: Event<String>) {
        switch event {
        case .next(let element):
            content.value = element
            
        case .error(let error):
            content.value = error.localizedDescription
            
        default:
            break
        }
    }
}

extension InputData: InputDataType {
    
    /// Return a new Notification.
    ///
    /// - Returns: A Notification instance.
    public static func notification(
        from components: [InputNotificationComponentType]
    ) -> InputNotificationType {
        return Notification(from: components)
    }
    
    /// Return identifier.
    public var inputIdentifier: String {
        guard let input = self.inputDetail else {
            debugException()
            return ""
        }
        
        return input.identifier
    }
    
    /// Return isRequired.
    public var isRequired: Bool {
        guard let input = self.inputDetail else {
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
    public var inputDataObservable: Observable<InputContentType> {
        return inputSubject.asObservable()
    }
    
    /// Return inputSubject as an Observer.
    public var inputDataObserver: AnyObserver<InputContentType> {
        return inputSubject.asObserver()
    }
    
    /// Check whether the input is empty.
    public var isEmpty: Bool {
        return inputContent.isEmpty
    }
    
    /// Produce a notification component based on existing input.
    ///
    /// - Parameter inputs: A Sequence of InputDataType to validate against.
    /// - Returns: An InputNotificationComponentType instance.
    public func notificationComponent<S: Sequence>(validatingAgainst inputs: S)
        -> InputNotificationComponentType
        where S.Iterator.Element: InputDataType
    {
        var component = InputData.Notification.Component()
        let value = inputContent
        component.key = inputIdentifier
        component.value = value
        
        if isRequired && value.isEmpty {
            component.error = "input.error.required".localized
        } else if let validator = inputValidator, value.isNotEmpty {
            // If the input is not required and empty, we do not worry about
            // it. The validation below applies to:
            //  - Required inputs that are not empty (empty required inputs
            //    should have thrown an error above).
            //  - Non-required inputs that are not empty - which indicates
            //    the user wants to change some non-crucial data.
            do {
                try validator.validate(input: self, against: inputs)
            } catch let e {
                component.error = e.localizedDescription
            }
        }
        
        return component
    }
}

public extension Sequence where Iterator.Element == InputContentType {
    
    /// Check if all required inputs are filled.
    ///
    /// - Returns: A Bool value.
    public func allRequiredInputFilled() -> Bool {
        for input in self {
            if input.isRequired && input.isEmpty { return false }
        }
        
        return true
    }
}

public extension Sequence where Iterator.Element: InputContentType {
    
    /// Check if all required inputs are filled.
    ///
    /// - Returns: A Bool value.
    public func allRequiredInputFilled() -> Bool {
        return map({$0 as InputContentType}).allRequiredInputFilled()
    }
}

public extension Sequence where Iterator.Element: InputDataType {
    
    /// Merge all inputListener into one Observable. We need to use merge
    /// because concat only takes the first element.
    ///
    /// - Returns: An Observable instance.
    public func rxInputObservables() -> Observable<InputContentType> {
        return self.map({$0.inputDataObservable}).mergeAsObservable()
    }
    
    /// Validate reactively and return an InputNotificationType.
    ///
    /// - Returns: An Observable instance.
    public func rxValidate() -> Observable<InputNotificationType> {
        return Observable.from(self)
            .map({$0.notificationComponent(validatingAgainst: self)})
            .toArray()
            .map({Iterator.Element.notification(from: $0)})
    }
    
    /// Check whether all required inputs have been filled.all
    ///
    /// - Returns: An Observable instance.
    public func rxAllRequiredInputFilled() -> Observable<Bool> {
        return Observable.combineLatest(self.map({$0.inputDataObservable}), {
            return $0.allRequiredInputFilled()
        })
    }
}

public extension Sequence where Iterator.Element == InputData {}
