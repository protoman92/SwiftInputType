//
//  InputDataTest.swift
//  SwiftUIUtilities
//
//  Created by Hai Pham on 4/19/17.
//  Copyright © 2017 Swiften. All rights reserved.
//

import RxTest
import RxSwift
import SwiftUtilities
import XCTest

fileprivate let validationDelay: RxTimeInterval = 0.1

final class InputDataTest: XCTestCase {
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
        let observer = scheduler.createObserver(Any.self)
        let expect = expectation(description: "Should have validated correctly")
        
        // When
        Observable.from(0..<100)
            .flatMap({_ in
                return Observable<[InputData]>.create({
                    let input1 = MockInput(required: Bool.random(),
                                           throwValidatorError: Bool.random())
                    
                    let input2 = MockInput(required: Bool.random(),
                                           throwValidatorError: Bool.random())
                    
                    let input3 = MockInput(required: Bool.random(),
                                           throwValidatorError: Bool.random())
                    
                    let inputData1 = InputData(for: input1)
                    let inputData2 = InputData(for: input2)
                    let inputData3 = InputData(for: input3)
                    $0.onNext([inputData1, inputData2, inputData3])
                    $0.onCompleted()
                    return Disposables.create()
                })
            })
            .doOnNext({
                $0[0].inputContent = Bool.random() ? "1" : ""
                $0[1].inputContent = Bool.random() ? "2" : ""
                $0[2].inputContent = Bool.random() ? "3" : ""
            })
            .flatMap({data in
                return self.validator.rxa_validateAll(inputs: data)
                    .subscribeOn(qos: .background)
                    .logNext()
                    .doOnNext({
                        if data.any(satisfying: {$0.isEmpty && $0.isRequired}) {
                            let emptyError = "input.error.required".localized
                            XCTAssertTrue($0.hasErrors)
                            XCTAssertTrue($0.hasError(emptyError))
                        } else {
                            let invalidInputs = data
                                .flatMap({$0.inputModel as? MockInput})
                                .filter({$0.throwValidatorError})
                            
                            let invalidData = invalidInputs.flatMap({
                                input -> InputData? in
                                let id = input.identifier
                                return data.first(where: {$0.hasIdentifier(id)})
                            })
                            
                            if invalidData.any(satisfying: {$0.isNotEmpty}) {
                                XCTAssertTrue($0.hasErrors)
                            }
                        }
                    })
            })
            .toArray()
            .cast(to: Any.self)
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .addDisposableTo(disposeBag)
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func test_requiredInputWatcher_shouldWork() {
        // Setup
        let observer = scheduler.createObserver(Bool.self)
        let input1 = MockInput(required: true, throwValidatorError: false)
        let input2 = MockInput(required: true, throwValidatorError: false)
        let input3 = MockInput(required: false, throwValidatorError: false)
        let inputData1 = InputData(for: input1)
        let inputData2 = InputData(for: input2)
        let inputData3 = InputData(for: input3)
        let inputData = [inputData1, inputData2, inputData3]
        
        // When
        validator
            .rxv_requiredInputFilled(inputs: inputData)
            .logNext()
            .subscribe(observer)
            .addDisposableTo(disposeBag)
        
        for _ in 0..<1000 {
            let randomInput = inputData.randomElement()!
            randomInput.inputContent = Bool.random() ? "Valid" : ""
            
            // Then
            let anyEmptyRequired = inputData.any(satisfying: {
                $0.isRequired && $0.isEmpty
            })
            
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
        let delay = validationDelay
        let scheduler = MainScheduler.asyncInstance
        return Observable.just(component).delay(delay, scheduler: scheduler)
    }
}
