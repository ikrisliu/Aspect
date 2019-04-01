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
    
    func testHookMethodWithSelectorType() {
        var invokeCount = 0
        let objc = NSObject()
        
        objc.hookSelector(with: #selector(doesNotRecognizeSelector(_:)), position: .instead, usingBlock: { aspect, selector in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.first as? String, "invalidSelector")
        } as @convention(block) (AspectObject, Selector) -> Void)
        
        objc.doesNotRecognizeSelector(NSSelectorFromString("invalidSelector"))
        
        XCTAssertEqual(invokeCount, 1)
    }
    
    func testHookMethodWithPointerType() {
        var invokeCount = 0
        let str = NSString(string: "abc")
        
        str.hookSelector(with: #selector(NSString.getCharacters(_:)), position: .after, usingBlock: { aspect in
            invokeCount += 1

            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)
        
        str.hookSelector(with: #selector(NSString.getCharacters(_:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertNotNil(aspect.arguments.first)
        } as AspectBlock)
        
        var char: unichar = 0
        str.getCharacters(&char)
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(char, 97)
    }
    
    func testHookMethodWithBlockType() {
        var invokeCount = 0
        let operation = BlockOperation()
        
        operation.hookSelector(with: #selector(BlockOperation.addExecutionBlock(_:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertNotNil(aspect.arguments.first)
        } as AspectBlock)
        
        operation.addExecutionBlock {
            sleep(1)
            invokeCount += 1
            XCTAssertEqual(invokeCount, 2)
        }
        
        XCTAssertEqual(invokeCount, 1)
    }
    
    func testAfterHookSelectorOfAllInstances() {
        var invokeCount = 0
        let userA = GuestUser()
        let userB = GuestUser()
        
        GuestUser.hookSelector(with: #selector(User.buy(productName:price:count:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            guard let target = aspect.instance as? User else { XCTFail(); return }
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertNotNil(target.productName)
            XCTAssertEqual(aspect.arguments.count, 3)
        } as AspectBlock)
        
        userA.buy(productName: "MacBook", price: NSNumber(value: 10000.23), count: NSNumber(value: 2))
        userB.buy(productName: "iPhone", price: NSNumber(value: 5000), count: NSNumber(value: 3))
        
        XCTAssertEqual(invokeCount, 2)
        XCTAssertEqual(userA.productName, "MacBook")
        XCTAssertEqual(userA.price, 10000.23)
        XCTAssertEqual(userA.count, 2)
        XCTAssertEqual(userB.productName, "iPhone")
        XCTAssertEqual(userB.price, 5000)
        XCTAssertEqual(userB.count, 3)
    }
    
    func testBeforeHookSelectorOfAllInstances() {
        var invokeCount = 0
        let user = UserBefore()
        
        UserBefore.hookSelector(with: #selector(UserBefore.buy(productName:price:count:)), position: .before, usingBlock: { aspect in
            invokeCount += 1
            guard let target = aspect.instance as? UserBefore else { XCTFail(); return }
            
            XCTAssertNotNil(target)
            XCTAssertNil(target.productName)
        } as AspectBlock)
        
        user.buy(productName: "MacBook", price: NSNumber(value: 10000), count: NSNumber(value: 5))
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(user.productName, "MacBook")
        XCTAssertEqual(user.price, 10000)
        XCTAssertEqual(user.count, 5)
    }
    
    func testInsteadHookSelectorOfAllInstances() {
        var invokeCount = 0
        let user = UserInstead()
        
        UserInstead.hookSelector(with: #selector(UserInstead.buy(productName:price:count:)), position: .instead, usingBlock: { aspect in
            invokeCount += 1
            guard let target = aspect.instance as? UserInstead else { XCTFail(); return }
            
            XCTAssertNotNil(target)
            XCTAssertNil(target.productName)
        } as AspectBlock)
        
        user.buy(productName: "MacBook", price: NSNumber(value: 10000), count: NSNumber(value: 2))
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertNil(user.productName)
    }
    
    func testAfterHookSelectorOfOneInstance() {
        var invokeCount = 0
        let user = UserAfter()
        
        user.hookSelector(with: #selector(UserAfter.buy(productName:price:count:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            let target = aspect.instance as! UserAfter
            XCTAssertNotNil(target)
            XCTAssertNotNil(target.productName)
            } as AspectBlock)
        
        user.buy(productName: "MacBook", price: NSNumber(value: 10000), count: NSNumber(value: 2))
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertNotNil(user.productName)
    }
    
    func testHookCustomObjectWithBlock() {
        var invokeCount = 0
        let user = RegisterUser()
        
        user.hookSelector(with: #selector(RegisterUser.buy(products:completion:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? RegisterUser {
                XCTAssertEqual(target, user)
                XCTAssertEqual(target.productName, "MacBook")
                XCTAssertEqual(target.price, 10000.23)
                XCTAssertEqual(target.count, 2)
                XCTAssertNotNil(target.completion)
            } else {
                XCTAssertNotNil(aspect.instance)
            }
            } as AspectBlock)
        
        let computer = Product(name: "MacBook", type: .computer, price: 10000.23, count: 2)
        user.buy(products: [computer], completion: { _ in })
        
        XCTAssertEqual(invokeCount, 1)
    }
    
    func testHookCustomObjectWithError() {
        var invokeCount = 0
        let user = RegisterUser()
        let indexPath = IndexPath(item: 5, section: 10)
        
        user.hookSelector(with: #selector(RegisterUser.buy(product:indexPath:error:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? RegisterUser {
                XCTAssertEqual(target, user)
                XCTAssertEqual(target.productName, "MacBook")
                XCTAssertEqual(target.price, 10000.23)
                XCTAssertEqual(target.count, 2)
                XCTAssertEqual(target.indexPath, indexPath)
                XCTAssertNotNil(target.error)
            } else {
                XCTAssertNotNil(aspect.instance)
            }
            } as AspectBlock)
        
        let computer = Product(name: "MacBook", type: .computer, price: 10000.23, count: 2)
        user.buy(product: computer, indexPath: indexPath, error: NSError(domain: "com.error", code: -1, userInfo: nil))
        
        XCTAssertEqual(invokeCount, 1)
    }
    
    func testHookSelectorWithMultipleTypeArguments() {
        var invokeCount = 0
        let userA = RegisterUser()
        let userB = RegisterUser()
        let indexPath = IndexPath(item: 5, section: 10)
        
        userA.hookSelector(with: #selector(RegisterUser.buy(productName:price:count:indexPath:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? RegisterUser {
                XCTAssertEqual(target, userA)
                XCTAssertNotEqual(target, userB)
                XCTAssertEqual(target.productName, "MacBook")
                XCTAssertEqual(target.price, 10000.23)
                XCTAssertEqual(target.count, 2)
                XCTAssertEqual(target.indexPath, indexPath)
            } else {
                XCTAssertNotNil(aspect.instance)
            }
        } as AspectBlock)
        
        #if os(OSX)
        userA.buy(productName: "MacBook", price: 10000.23, count: 2, indexPath: indexPath)
        userB.buy(productName: "iPhone", price: 5000, count: 3, indexPath: IndexPath(item: 2, section: 7))
        #else
        userA.buy(productName: "MacBook", price: NSNumber(value: 10000.23), count: NSNumber(value: 2), indexPath: indexPath)
        userB.buy(productName: "iPhone", price: NSNumber(value: 5000), count: NSNumber(value: 3), indexPath: IndexPath(item: 2, section: 7))
        #endif
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(userA.productName, "MacBook")
        XCTAssertEqual(userA.price, 10000.23)
        XCTAssertEqual(userA.count, 2)
    }
    
    func testHookSameSelectorInDistinctClasses() {
        var invokeACount = 0
        var invokeBCount = 0
        
        Cat.hookSelector(with: #selector(Cat.run), position: .after, usingBlock: { aspect in
            invokeACount += 1
            XCTAssertNotNil(aspect.instance)
            } as AspectBlock)
        
        Dog.hookSelector(with: #selector(Dog.run), position: .after, usingBlock: { aspect in
            invokeBCount += 1
            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)
        
        Cat.run()
        Dog.run()
        
        XCTAssertEqual(invokeACount, 1)
        XCTAssertEqual(invokeBCount, 1)
    }
    
    func testHookMethodWithEnumAndBoolType() {
        var invokeCount = 0
        
        User.hookSelector(with: #selector(User.exit), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 0)
        } as AspectBlock)
        
        User.exit()
        User.exit()
        
        XCTAssertEqual(invokeCount, 2)
    }
    
    func testHookNoImplementationSelector() {
        var invokeCount = 0
        let userA = User()
        let userB = User()
        
        User.hookSelector(with: #selector(RegisterUser.login(type:needPassword:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 2)
            XCTAssertEqual(aspect.arguments.last as! Bool, true)
            } as AspectBlock)
        
        userA.login(type: .mobile, needPassword: true)
        userB.login(type: .email, needPassword: true)
        
        XCTAssertEqual(invokeCount, 2)
        XCTAssertEqual(userA.loginType, LoginType.mobile)
        XCTAssertEqual(userB.loginType, LoginType.email)
    }
}


@objc private enum LoginType: Int {
    
    case mobile = 7
    case email = 8
}

private class User: NSObject {
    
    var loginType: LoginType?
    
    var products: [Product] = []
    var productName: String!
    var price: Double!
    var count: Int!
    var indexPath: IndexPath?
    var completion: ((Bool) -> Void)?
    var error: NSError?
    
    @objc dynamic static func exit() {}
    
    @objc dynamic func login(type: LoginType, needPassword: Bool) {
        loginType = type
    }
    
    @objc dynamic func buy(productName: String, price: NSNumber, count: NSNumber) {
        self.productName = productName
        self.price = price.doubleValue
        self.count = count.intValue
    }
    
    #if os(OSX)
    @objc dynamic func buy(productName: String, price: Double, count: Int, indexPath: IndexPath) {
        self.productName = productName
        self.price = price
        self.count = count
        self.indexPath = indexPath
    }
    #else
    @objc dynamic func buy(productName: String, price: NSNumber, count: NSNumber, indexPath: IndexPath) {
        self.productName = productName
        self.price = price.doubleValue
        self.count = count.intValue
        self.indexPath = indexPath
    }
    #endif
    
    @objc dynamic func buy(products: [Product], completion: ((Bool) -> Void)?) {
        self.products = products
        self.productName = products.first?.name
        self.price = products.first?.price
        self.count = products.first?.count
        self.completion = completion
    }
    
    @objc dynamic func buy(product: Product, indexPath: IndexPath, error: NSError?) {
        self.productName = product.name
        self.price = product.price
        self.count = product.count
        self.indexPath = indexPath
        self.error = error
    }
}

private class GuestUser: User {}
private class RegisterUser: User {}
private class UserAfter: User {}
private class UserBefore: User {}
private class UserInstead: User {}

private class Product: NSObject {
    
    enum ProductType: Int {
        case phone
        case computer
    }
    
    let name: String
    let type: ProductType
    let price: Double
    let count: Int
    
    init(name: String, type: ProductType, price: Double, count: Int) {
        self.name = name
        self.type = type
        self.price = price
        self.count = count
    }
}

private class Cat: NSObject {
    
    @objc dynamic static func run() {}
}

private class Dog: NSObject {
    
    @objc dynamic static func run() {}
}
