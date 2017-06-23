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
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        disposeBag = DisposeBag()
        scheduler = TestScheduler(initialClock: 0)
    }
    
    func test_inputDataAsObservable_shouldSucceed() {
        // Setup
        let observer = scheduler.createObserver(Any.self)
        
        let input1 = InputData.builder()
            .with(input: MockInput.input1)
            .build()
        
        let input2 = InputData.builder()
            .with(input: MockInput.input2)
            .build()
        
        let input3 = InputData.builder()
            .with(input: MockInput.input3)
            .build()
        
        let inputs = [input1, input2, input3]
        
        // When
        _ = inputs.rxInputObservables()
            .logNext()
            .cast(to: Any.self)
            .subscribe(observer)
        
        input1.inputContent = ""
        input2.inputContent = ""
        input3.inputContent = ""
        input1.inputContent = "Test input 1"
        input2.inputContent = "Test input 2"
        input3.inputContent = "Test input 3"
        input1.inputContent = "Test input 1-1"
        input2.inputContent = "Test input 2-2"
        input3.inputContent = "Test input 3-3"
        
        // Then
        print(observer.events.count)
    }
    
    func test_inputDataContentListener_shouldSucceed() {
        // Setup
        let observer = scheduler.createObserver(Any.self)
        let subject = PublishSubject<String>()
        
        let input1 = InputData.builder()
            .with(input: MockInput.input1)
            .build()
        
        let input2 = InputData.builder()
            .with(input: MockInput.input2)
            .build()
        
        let input3 = InputData.builder()
            .with(input: MockInput.input3)
            .build()
        
        // When
        _ = subject
            .doOnNext(input1.onNext)
            .doOnNext(input2.onNext)
            .doOnNext(input3.onNext)
            .cast(to: Any.self)
            .subscribe(observer)
        
        subject.onNext("Test1")
        subject.onNext("Test2")
        subject.onNext("Test3")
        
        // Then
        print(observer.events)
    }
    
    func test_inputValidator_shouldSucceed() {
        // Setup
        let observer = scheduler.createObserver(InputNotificationType.self)
        let confirmSubject = PublishSubject<Bool>()
        var inputData = [InputData]()
        
        // When
        confirmSubject
            .flatMap({_ in inputData.rxValidate()})
            .subscribe(observer)
            .addDisposableTo(disposeBag)
        
        for _ in 0..<1000 {
            let input1 = MockInput(required: Bool.random(),
                                   throwValidatorError: Bool.random())
            
            let input2 = MockInput(required: Bool.random(),
                                   throwValidatorError: Bool.random())
            
            let input3 = MockInput(required: Bool.random(),
                                   throwValidatorError: Bool.random())
            
            let inputData1 = InputData.builder()
                .with(input: input1)
                .with(inputValidator: input1)
                .build()
            
            let inputData2 = InputData.builder()
                .with(input: input2)
                .with(inputValidator: input2)
                .build()
            
            let inputData3 = InputData.builder()
                .with(input: input3)
                .with(inputValidator: input3)
                .build()
            
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
                
                XCTAssertTrue(lastEvent.outputs.any(satisfying: {
                    $0.value == "input.error.required".localized
                }))
                
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
        _ = inputData.rxAllRequiredInputFilled().subscribe(observer)
        
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

extension MockInput: CustomStringConvertible {
    var description: String {
        return "\(required)-\(throwValidatorError)-\(count)"
    }
}

extension MockInput: InputDetailType {
    var identifier: String { return String(describing: self) }
    var isRequired: Bool { return required }
}

extension MockInput: InputValidatorType {
    func validate<S: Sequence>(input: InputDataType, against inputs: S)
        throws where S.Iterator.Element : InputDataType
    {
        if throwValidatorError { throw Exception("Error!!!") }
    }
}
