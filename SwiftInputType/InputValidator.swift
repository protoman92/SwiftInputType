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
    ///   - input: The InputDataType to be validated.
    ///   - inputs: A Sequence of InputDataType to validate against.
    /// - Returns: An Observable instance.
    func rxa_validate<S: Sequence>(input: InputDataType, against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputDataType
}

public extension InputValidatorType {
    
    /// Get all empty required inputs. We can subscribe to this Observable
    /// to be notified when an InputDataType was recently emptied.
    ///
    /// - Parameter inputs: Sequence of InputDataType.
    /// - Returns: An Observable instance.
    public func rxe_emptyRequiredInputs<S: Sequence>(inputs: S)
        -> Observable<InputContentType>
        where S.Iterator.Element: InputDataType
    {
        return Observable
            .combineLatest(inputs.map({$0.inputObservable}), eq)
            .flatMap({data in Observable.from(data)})
            .filter({$0.isEmpty})
    }
    
    /// Check whether all required inputs have been filled.
    ///
    /// - Returns: An Observable instance.
    public func rxv_requiredInputFilled<S: Sequence>(inputs: S)
        -> Observable<Bool> where S.Iterator.Element: InputDataType
    {
        return Observable.combineLatest(inputs.map({$0.inputObservable}), {
            return !$0.any(satisfying: {$0.isRequired && $0.isEmpty})
        })
    }
    
    /// First check whether the input is required and non-empty, then validate.
    ///
    /// - Parameters:
    ///   - input: The InputDataType to be validated.
    ///   - inputs: A Sequence of InputDataType to validate against.
    /// - Returns: An Observable instance.
    public func rxa_requiredAndValidate<S: Sequence>(input: InputDataType,
                                        against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputDataType
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
    
    /// Validate multiple InputDataType.
    ///
    /// - Parameter inputs: Sequence of InputDataType.
    /// - Returns: Observable instance.
    public func rxa_validate<S: Sequence>(inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element: InputDataType
    {
        return Observable.from(inputs)
            .flatMap({self.rxa_requiredAndValidate(input: $0, against: inputs)})
            .observeOn(MainScheduler.instance)
    }
    
    /// Validate multiple InputDataType and concatenate all 
    /// InputNotificationComponentType into one InputNotificationType.
    ///
    /// - Parameter inputs: Sequence of InputDataType.
    /// - Returns: An Observable instance.
    public func rxa_validateAll<S: Sequence>(inputs: S)
        -> Observable<InputNotificationType>
        where S.Iterator.Element: InputDataType
    {
        return rxa_validate(inputs: inputs).toArray().map(InputNotification.init)
    }
}
