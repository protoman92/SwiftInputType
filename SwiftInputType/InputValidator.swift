//
//  InputValidator.swift
//  SwiftInputType
//
//  Created by Hai Pham on 6/24/17.
//  Copyright © 2017 Swiften. All rights reserved.
//

import RxSwift
import SwiftUtilities

/// Implement this protocol to provide validation.
public protocol InputValidatorType {
    
    /// Validate an input against a Sequence of inputs.
    ///
    /// - Parameters:
    ///   - input: The InputContentType to be validated.
    ///   - inputs: A Sequence of InputContentType to validate against.
    /// - Returns: An Observable instance.
    func rxa_validate<S: Sequence>(input: InputContentType, against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element == InputContentType
}

public extension InputValidatorType {
    
    /// Same as above, but uses a Sequence of InputContentType subclass.
    ///
    /// - Parameters:
    ///   - input: The InputContentType to be validated.
    ///   - inputs: A Sequence of InputContentType to validate against.
    /// - Returns: An Observable instance.
    public func rxa_validate<S: Sequence>(input: InputContentType,
                             against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputContentType
    {
        let inputs = inputs.map(eq) as [InputContentType]
        return rxa_validate(input: input, against: inputs)
    }
}

public extension InputValidatorType {
    
    /// Get all empty required inputs. We can subscribe to this Observable
    /// to be notified when an InputDataType was recently emptied.
    ///
    /// - Parameter inputs: Sequence of InputDataType.
    /// - Returns: An Observable instance.
    public func rxe_emptyRequiredInputsLatest<S: Sequence>(inputs: S)
        -> Observable<InputContentType>
        where S.Iterator.Element == InputDataType
    {
        return Observable
            .combineLatest(inputs.map({$0.inputObservable}), eq)
            .flatMap({data in Observable.from(data)})
            .filter({$0.isEmpty})
    }
    
    /// Same as above, but uses a Sequence of InputDataType subclass.
    ///
    /// - Parameter inputs: Sequence of InputDataType.
    /// - Returns: An Observable instance.
    public func rxe_emptyRequiredInputsLatest<S: Sequence>(inputs: S)
        -> Observable<InputContentType>
        where S.Iterator.Element: InputDataType
    {
        let inputs = inputs.map(eq) as [InputDataType]
        return rxe_emptyRequiredInputsLatest(inputs: inputs)
    }
}

public extension InputValidatorType {
    
    /// Check whether all required inputs have been filled.
    ///
    /// - Returns: An Observable instance.
    public func rxv_requiredInputFilledLatest<S: Sequence>(inputs: S)
        -> Observable<Bool>
        where S.Iterator.Element == InputDataType
    {
        return Observable.combineLatest(inputs.map({$0.inputObservable}), {
            return !$0.any(satisfying: {$0.isRequired && $0.isEmpty})
        })
    }
    
    /// Same as above, but uses a Sequence of InputDataType subclass.
    ///
    /// - Returns: An Observable instance.
    public func rxv_requiredInputFilledLatest<S: Sequence>(inputs: S)
        -> Observable<Bool>
        where S.Iterator.Element: InputDataType
    {
        let inputs = inputs.map(eq) as [InputDataType]
        return rxv_requiredInputFilledLatest(inputs: inputs)
    }
}

public extension InputValidatorType {
    
    /// First check whether the input is required and non-empty, then validate.
    ///
    /// - Parameters:
    ///   - input: The InputContentType to be validated.
    ///   - inputs: A Sequence of InputContentType to validate against.
    /// - Returns: An Observable instance.
    public func rxa_requireAndValidate<S: Sequence>(input: InputContentType,
                                       against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element == InputContentType
    {
        let isRequired = input.isRequired
        let key = input.inputIdentifier
        let value = input.inputContent
        
        if isRequired && value.isEmpty {
            let component = InputNotification.componentBuilder()
                .with(key: key)
                .with(value: value)
                .with(error: "input.error.required".localized)
                .build()
            
            return Observable.just(component)
        } else {
            return self
                .rxa_validate(input: input, against: inputs)
                .subscribeOn(qos: .background)
        }
    }
    
    /// Same as above, but uses a Sequence of InputContentType subclass.
    ///
    /// - Parameters:
    ///   - input: The InputContentType to be validated.
    ///   - inputs: A Sequence of InputContentType to validate against.
    /// - Returns: An Observable instance.
    public func rxa_requireAndValidate<S: Sequence>(input: InputContentType,
                                       against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputContentType
    {
        let inputs = inputs.map(eq) as [InputContentType]
        return rxa_requireAndValidate(input: input, against: inputs)
    }
}

public extension InputValidatorType {

    /// Validate multiple InputDataType.
    ///
    /// - Parameter inputs: Sequence of InputContentType.
    /// - Returns: Observable instance.
    public func rxa_validate<S: Sequence>(inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element == InputContentType
    {
        return Observable.from(inputs)
            .flatMap({self.rxa_requireAndValidate(input: $0, against: inputs)})
            .observeOn(MainScheduler.instance)
    }
    
    /// Same as above, but uses a Sequence of InputContentType subclass.
    ///
    /// - Parameter inputs: Sequence of InputContentType.
    /// - Returns: Observable instance.
    public func rxa_validate<S: Sequence>(inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputContentType
    {
        return rxa_validate(inputs: inputs.map(eq) as [InputContentType])
    }
}

public extension InputValidatorType {

    /// This variant validates against the latest inputs, whenever the
    /// underlying content for one (or more) InputContentType changes.
    /// It is not possible to create an InputNotificationType, because there
    /// is no onComplete event, and as such, toArray() does not work.
    ///
    /// - Parameter inputs: Sequence of InputContentType.
    /// - Returns: Observable instance.
    public func rxa_validateLatest<S: Sequence>(inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element == InputDataType
    {
        return Observable
            .combineLatest(inputs.map({$0.inputObservable}), eq)
            .flatMap(self.rxa_validate)
    }
    
    /// Same as above, but uses a Sequence of InputDataType subclass.
    ///
    /// - Parameter inputs: Sequence of InputContentType.
    /// - Returns: Observable instance.
    public func rxa_validateLatest<S: Sequence>(inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputDataType
    {
        return rxa_validateLatest(inputs: inputs.map(eq) as [InputDataType])
    }
}

public extension InputValidatorType {

    /// Validate multiple InputDataType and concatenate all 
    /// InputNotificationComponentType into one InputNotificationType.
    ///
    /// - Parameter inputs: Sequence of InputDataType.
    /// - Returns: An Observable instance.
    public func rxa_validateAll<S: Sequence>(inputs: S)
        -> Observable<InputNotificationType>
        where S.Iterator.Element: InputContentType
    {
        return rxa_validate(inputs: inputs).toArray().map(InputNotification.init)
    }
}
