//
//  InputDataTest.swift
//  SwiftUIUtilities
//
//  Created by Hai Pham on 4/19/17.
//  Copyright © 2017 Swiften. All rights reserved.
//

import RxTest
import RxSwift
import XCTest

class InputDataTest: XCTestCase {
    fileprivate var disposeBag: DisposeBag!
    fileprivate var scheduler: TestScheduler!
    fileprivate var validator: MockInputValidator!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        disposeBag = DisposeBag()
        validator = MockInputValidator()
        scheduler = TestScheduler(initialClock: 0)
    }
    
    func test_inputValidator_shouldSucceed() {
        // Setup
        let observer = scheduler.createObserver(InputNotificationType.self)
        let confirmSubject = PublishSubject<Bool>()
        var inputData = [InputData]()
        
        // When
        confirmSubject
            .flatMap({_ in self.validator.rxa_validate(inputs: inputData)})
            .subscribe(observer)
            .addDisposableTo(disposeBag)
        
        for _ in 0..<1000 {
            let input1 = MockInput(required: Bool.random(),
                                   throwValidatorError: Bool.random())
            
            let input2 = MockInput(required: Bool.random(),
                                   throwValidatorError: Bool.random())
            
            let input3 = MockInput(required: Bool.random(),
                                   throwValidatorError: Bool.random())
            
            let inputData1 = InputData.builder().with(input: input1).build()
            let inputData2 = InputData.builder().with(input: input2).build()
            let inputData3 = InputData.builder().with(input: input3).build()
            
            let inputs = [input1, input2, input3]
            inputData = [inputData1, inputData2, inputData3]
            inputData1.inputContent = Bool.random() ? "1" : ""
            inputData2.inputContent = Bool.random() ? "2" : ""
            inputData3.inputContent = Bool.random() ? "3" : ""
            confirmSubject.onNext(true)
            
            // Then
            let lastEvent = observer.events.last!.value.element!
            
            if inputData.any(satisfying: {$0.isEmpty && $0.isRequired}) {
                XCTAssertTrue(lastEvent.hasErrors)
                XCTAssertTrue(lastEvent.hasError("input.error.required".localized))
            } else {
                let invalidInputs = inputs.filter({$0.throwValidatorError})
                
                let invalidData = invalidInputs.flatMap({input in
                    inputData.filter({
                        $0.inputIdentifier == input.identifier
                    }).first
                })
                
                if invalidData.any(satisfying: {$0.inputContent.isNotEmpty}) {
                    XCTAssertTrue(lastEvent.hasErrors)
                }
            }
        }
    }
    
    func test_requiredInputWatcher_shouldWork() {
        // Setup
        let observer = scheduler.createObserver(Bool.self)
        let input1 = MockInput(required: true, throwValidatorError: false)
        let input2 = MockInput(required: true, throwValidatorError: false)
        let input3 = MockInput(required: false, throwValidatorError: false)
        let inputData1 = InputData.builder().with(input: input1).build()
        let inputData2 = InputData.builder().with(input: input2).build()
        let inputData3 = InputData.builder().with(input: input3).build()
        let inputData = [inputData1, inputData2, inputData3]
        
        // When
        _ = validator
            .rxv_allRequiredInputFilled(inputs: inputData)
            .subscribe(observer)
        
        for _ in 0..<1000 {
            let randomInput = inputData.randomElement()!
            randomInput.inputContent = Bool.random() ? "Valid" : ""
            
            // Then
            let anyEmptyRequired = inputData.filter({
                $0.isRequired && $0.isEmpty
            }).isNotEmpty
            
            let lastEvent = observer.events.last?.value.element!
            XCTAssertNotEqual(lastEvent, anyEmptyRequired)
        }
    }
}

class MockInput {
    static var counter = 0
    
    static var input1 = MockInput()
    static var input2 = MockInput()
    static var input3 = MockInput()
    
    fileprivate let required: Bool
    fileprivate let throwValidatorError: Bool
    fileprivate let count: Int
    
    init(required: Bool, throwValidatorError: Bool) {
        MockInput.counter += 1
        self.required = required
        self.throwValidatorError = throwValidatorError
        count = MockInput.counter
    }
    
    convenience init() {
        self.init(required: false, throwValidatorError: false)
    }
}

class MockInputValidator {}

extension MockInput: CustomStringConvertible {
    var description: String {
        return "\(required)-\(throwValidatorError)-\(count)"
    }
}

extension MockInput: InputType {
    var identifier: String { return String(describing: self) }
    var isRequired: Bool { return required }
}

extension MockInputValidator: InputValidatorType {
    func rxa_validate<S: Sequence>(input: InputDataType, against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element : InputDataType
    {
        let mockInput = input.inputModel as! MockInput
        
        let builder = InputNotification.componentBuilder()
            .with(keyProvider: input)
            .with(valueProvider: input)
        
        if mockInput.throwValidatorError {
            builder.with(error: "Invalid input")
        }
        
        let component = builder.build()
        return Observable.just(component)
    }
}
