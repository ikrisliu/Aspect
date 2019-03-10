//
//  AspectTests.swift
//  AspectTests
//
//  Created by Kris Liu on 2019/3/10.
//  Copyright © 2019 Syzygy. All rights reserved.
//

import XCTest
@testable import Aspect

class AspectTests: XCTestCase {
    
    func testAfterHookSelectorOfAllInstances() {
        var invokeCount = 0
        let vc = ViewControllerAfter()
        let anotherVC = ViewControllerAfter()
        
        ViewControllerAfter.hookSelector(with: #selector(ViewControllerAfter.buy(productName:price:count:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 3)
            } as AspectBlock)
        
        vc.buy(productName: "MacBook", price: NSNumber(value: 10000.23), count: NSNumber(value: 2))
        anotherVC.buy(productName: "iPhone", price: NSNumber(value: 5000), count: NSNumber(value: 3))
        
        XCTAssertEqual(invokeCount, 2)
    }
    
    func testBeforeHookSelectorOfAllInstances() {
        var invokeCount = 0
        let vc = ViewControllerBefore()
        
        ViewControllerBefore.hookSelector(with: #selector(ViewControllerBefore.buy(productName:price:count:)), position: .before, usingBlock: { aspect in
            invokeCount += 1
            let target = aspect.instance as! ViewControllerBefore
            XCTAssertNotNil(target)
            XCTAssertNil(target.productName)
            } as AspectBlock)
        
        vc.buy(productName: "MacBook", price: NSNumber(value: 10000), count: NSNumber(value: 2))
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertNotNil(vc.productName)
    }
    
    func testInsteadHookSelectorOfAllInstances() {
        var invokeCount = 0
        let vc = ViewControllerInstead()
        
        ViewControllerInstead.hookSelector(with: #selector(ViewControllerInstead.buy(productName:price:count:)), position: .instead, usingBlock: { aspect in
            invokeCount += 1
            let target = aspect.instance as! ViewControllerInstead
            XCTAssertNotNil(target)
            XCTAssertNil(target.productName)
            } as AspectBlock)
        
        vc.buy(productName: "MacBook", price: NSNumber(value: 10000), count: NSNumber(value: 2))
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertNil(vc.productName)
    }
    
    func testAfterHookSelectorOfOneInstance() {
        var invokeCount = 0
        let vc = ViewControllerAfterOne()
        let anotherVC = ViewControllerAfterOne()
        let indexPath = IndexPath(row: 5, section: 10)
        
        vc.hookSelector(with: #selector(ViewControllerAfterOne.buy(productName:price:count:indexPath:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? ViewControllerAfterOne {
                XCTAssertEqual(target, vc)
                XCTAssertNotEqual(target, anotherVC)
                XCTAssertEqual(target.productName, "MacBook")
                XCTAssertEqual(target.price, 10000.23)
                XCTAssertEqual(target.count, 2)
                XCTAssertEqual(target.indexPath, indexPath)
            } else {
                XCTAssertNotNil(aspect.instance)
            }
            } as AspectBlock)
        
        vc.buy(productName: "MacBook", price: NSNumber(value: 10000.23), count: NSNumber(value: 2), indexPath: indexPath)
        anotherVC.buy(productName: "iPhone", price: NSNumber(value: 5000), count: NSNumber(value: 3), indexPath: IndexPath(row: 2, section: 7))
        
        XCTAssertEqual(invokeCount, 1)
    }
    
    func testHookSameSelectorInDistinctClasses() {
        var invokeACount = 0
        var invokeBCount = 0
        
        ViewControllerA.hookSelector(with: #selector(ViewControllerA.login), position: .after, usingBlock: { aspect in
            invokeACount += 1
            XCTAssertNotNil(aspect.instance)
            } as AspectBlock)
        
        ViewControllerB.hookSelector(with: #selector(ViewControllerB.login), position: .after, usingBlock: { aspect in
            invokeBCount += 1
            XCTAssertNotNil(aspect.instance)
            } as AspectBlock)
        
        ViewControllerA.login()
        ViewControllerB.login()
        
        XCTAssertEqual(invokeACount, 1)
        XCTAssertEqual(invokeBCount, 1)
    }
    
    func testHookNoImplementationSelector() {
        var invokeCount = 0
        
        ViewController.hookSelector(with: #selector(ViewController.viewDidAppear(_:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 1)
            XCTAssertEqual(aspect.arguments.first as! Bool, true)
            } as AspectBlock)
        
        ViewController().viewDidAppear(true)
        ViewController().viewDidAppear(true)
        
        XCTAssertEqual(invokeCount, 2)
    }
}


private class ViewController: UIViewController {
    
    var productName: String!
    var price: Double!
    var count: Int!
    var indexPath: IndexPath?
    
    @objc dynamic static func login() {}
    
    @objc dynamic func buy(productName: String, price: NSNumber, count: NSNumber) {
        self.productName = productName
        self.price = price.doubleValue
        self.count = count.intValue
    }
    
    @objc dynamic func buy(productName: String, price: NSNumber, count: NSNumber, indexPath: IndexPath) {
        self.productName = productName
        self.price = price.doubleValue
        self.count = count.intValue
        self.indexPath = indexPath
    }
}

private class ViewControllerAfter: ViewController {}
private class ViewControllerAfterOne: ViewController {}
private class ViewControllerBefore: ViewController {}
private class ViewControllerInstead: ViewController {}

private class ViewControllerA: UIViewController {
    @objc dynamic static func login() {}
}

private class ViewControllerB: UIViewController {
    @objc dynamic static func login() {}
}
