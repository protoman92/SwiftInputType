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
import SwiftUtilitiesTests
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
    
    override func tearDown() {
        super.tearDown()
        disposeBag = nil
    }
    
    func createInputData() -> [InputData] {
        return (0..<10).map(toVoid).map(MockInput.init).map(InputData.init)
    }
    
    func test_inputData_shouldBeEmptyAtFirst() {
        // Setup
        let observer = scheduler.createObserver(String.self)
        let data = createInputData()
        
        // When
        Observable.from(data)
            .flatMap({$0.inputObservable})
            .map({$0.inputContent})
            .subscribe(observer)
            .addDisposableTo(disposeBag)
        
        // Then
        let nextEvents = observer.nextElements()
        XCTAssertFalse(nextEvents.isEmpty)
        XCTAssertTrue(nextEvents.all(satisfying: {$0.isEmpty}))
    }
    
    func test_validateInputNormally_shouldSucceed() {
        // Setup
        let observer = scheduler.createObserver(Any.self)
        let expect = expectation(description: "Should have validated correctly")
        
        // When
        Observable.from(0..<100)
            .flatMap({_ in
                return Observable<[InputData]>.create({
                    let data = self.createInputData()
                    $0.onNext(data)
                    $0.onCompleted()
                    return Disposables.create()
                })
            })
            .doOnNext({
                $0.enumerated().forEach({
                    let newInput = String(describing: $0.offset)
                    let data = $0.element
                    data.inputContent = Bool.random() ? newInput : ""
                })
            })
            .flatMap({data in
                return self.validator
                    .rxa_validateAll(inputs: data as [InputContentType])
                    .subscribeOn(qos: .background)
                    .doOnNext({
                        // Then
                        if data.any(satisfying: {$0.isEmpty && $0.isRequired}) {
                            let emptyError = "input.error.required".localized
                            XCTAssertTrue($0.hasErrors)
                            XCTAssertTrue($0.hasError(emptyError))
                        } else {
                            let invalidInputs = data
                                .flatMap({$0.inputModel as? MockInput})
                                .filter({$0.validationError})
                            
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
        
        waitForExpectations(timeout: 100, handler: nil)
    }

    
    func test_validateLatest_shouldWork() {
        // Setup
        let observer = scheduler.createObserver(InputNotificationComponentType.self)
        let data = createInputData()
        
        // When
        validator
            .rxa_validateLatest(inputs: data)
            .subscribe(observer)
            .addDisposableTo(disposeBag)
        
        for _ in 1...100 {
            let randomInput = data.randomElement()!
            randomInput.inputContent = String.random(withLength: 5)
            
            // Need to sleep for a bit to wait for validation delay
            usleep(useconds_t(validationDelay * 1000 + 1))
            
            let events = observer.nextElements()
            let notification = InputNotification(from: events)
            
            // Then
            if data.any(satisfying: {$0.isEmpty && $0.isRequired}) {
                let emptyError = "input.error.required".localized
                XCTAssertTrue(notification.hasErrors)
                XCTAssertTrue(notification.hasError(emptyError))
            } else {
                let invalidInputs = data
                    .flatMap({$0.inputModel as? MockInput})
                    .filter({$0.validationError})
                
                let invalidData = invalidInputs.flatMap({input -> InputData? in
                    return data.first(where: {$0.hasIdentifier(input.identifier)})
                })
                
                if invalidData.any(satisfying: {$0.isNotEmpty}) {
                    XCTAssertTrue(notification.hasErrors)
                }
            }
        }
    }
    
    func test_watchRequiredInputLatest_shouldWork() {
        // Setup
        let observer1 = scheduler.createObserver(Bool.self)
        let observer2 = scheduler.createObserver(InputContentType.self)
        let data = createInputData()
        
        // When
        validator.rxv_requiredInputFilledLatest(inputs: data)
            .subscribe(observer1)
            .addDisposableTo(disposeBag)
        
        validator.rxe_emptyRequiredInputsLatest(inputs: data)
            .subscribe(observer2)
            .addDisposableTo(disposeBag)
        
        for _ in 0..<5 {
            let randomInput = data.randomElement()!
            randomInput.inputContent = Bool.random() ? "Valid" : ""
            
            // Then
            let failed = data.any(satisfying: {$0.isRequired && $0.isEmpty})
            let lastEvent1 = observer1.events.last?.value.element!
            let events2 = observer2.nextElements()
            XCTAssertFalse(events2.isEmpty)
            XCTAssertNotEqual(lastEvent1, failed)
            XCTAssertTrue(events2.all(satisfying: {$0.isEmpty}))
        }
    }
}

class MockInput {
    static var counter = 0
    
    fileprivate let required: Bool
    fileprivate let validationError: Bool
    fileprivate let count: Int
    
    init(required: Bool, validationError: Bool) {
        MockInput.counter += 1
        self.required = required
        self.validationError = validationError
        count = MockInput.counter
    }
    
    convenience init() {
        self.init(required: Bool.random(), validationError: Bool.random())
    }
}

class MockInputValidator {}

extension MockInput: CustomStringConvertible {
    var description: String {
        return "\(required)-\(validationError)-\(count)"
    }
}

extension MockInput: InputType {
    var identifier: String { return String(describing: self) }
    var isRequired: Bool { return required }
}

extension MockInputValidator: InputValidatorType {
    func rxa_validate<S: Sequence>(input: InputContentType, against inputs: S)
        -> Observable<InputNotificationComponentType>
        where S.Iterator.Element == InputContentType
    {
        let mockInput = input.inputModel as! MockInput
        
        let builder = InputNotification.componentBuilder()
            .with(keyProvider: input)
            .with(valueProvider: input)
        
        if mockInput.validationError {
            builder.with(error: "Invalid input")
        }
        
        let component = builder.build()
        let delay = validationDelay
        let scheduler = MainScheduler.asyncInstance
        return Observable.just(component).delay(delay, scheduler: scheduler)
    }
}
