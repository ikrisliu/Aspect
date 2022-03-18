//
//  AspectTests.swift
//  AspectTests
//
//  Created by Kris Liu on 2019/3/10.
//  Copyright © 2022 Gravity. All rights reserved.
//

import XCTest
@testable import Aspect

class AspectTests: XCTestCase {
    
    func testHookMethodWithSelectorType() {
        var invokeCount = 0
        let objc = NSObject()
        
        objc.hook(#selector(doesNotRecognizeSelector(_:)), position: .instead, usingBlock: { aspect, selector in
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
        
        str.hook(#selector(NSString.getCharacters(_:)), position: .after, usingBlock: { aspect in
            invokeCount += 1

            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)
        
        str.hook(#selector(NSString.getCharacters(_:)), position: .after, usingBlock: { aspect in
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
        
        operation.hook(#selector(BlockOperation.addExecutionBlock(_:)), position: .after, usingBlock: { aspect in
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
        let size = CGSize(width: 20.45, height: 30.3)
        let userA = User()
        let userB = User()
        
        User.hook(#selector(User.buy(productName:price:count:size:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            guard let target = aspect.instance as? User else { XCTFail(); return }
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertNotNil(target.productName)
            XCTAssertNotNil(target.price)
            XCTAssertNotNil(target.size)
            XCTAssertEqual(aspect.arguments.count, 4)
        } as AspectBlock)
        
        userA.buy(productName: "MacBook", price: 10000.23, count: 2, size: .zero)
        userB.buy(productName: "iPhone", price: 5000, count: 5, size: size)
        
        XCTAssertEqual(invokeCount, 2)
        XCTAssertEqual(userA.productName, "MacBook")
        XCTAssertEqual(userA.price, 10000.23)
        XCTAssertEqual(userA.count, 2)
        XCTAssertEqual(userA.size, CGSize.zero)
        XCTAssertEqual(userB.productName, "iPhone")
        XCTAssertEqual(userB.price, 5000)
        XCTAssertEqual(userB.count, 5)
        XCTAssertEqual(userB.size, size)
    }
    
    func testBeforeHookSelectorOfAllInstances() {
        var invokeCount = 0
        let size = CGSize(width: 10, height: 20)
        let user = User()
        
        User.unhookSelector(#selector(User.buy(productName:price:count:size:)))
        User.hook(#selector(User.buy(productName:price:count:size:)), position: .before, usingBlock: { aspect in
            invokeCount += 1
            guard let target = aspect.instance as? User else { XCTFail(); return }
            
            XCTAssertNotNil(target)
            XCTAssertNil(target.productName)
        } as AspectBlock)
        
        user.buy(productName: "MacBook", price: 10000, count: 5, size: size)
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(user.productName, "MacBook")
        XCTAssertEqual(user.price, 10000)
        XCTAssertEqual(user.count, 5)
        XCTAssertEqual(user.size, size)
    }
    
    func testInsteadHookSelectorOfAllInstances() {
        var invokeCount = 0
        let size = CGSize(width: 100, height: 200)
        let user = User()
        
        User.unhookSelector(#selector(User.buy(productName:price:count:size:)))
        User.hook(#selector(User.buy(productName:price:count:size:)), position: .instead, usingBlock: { aspect in
            invokeCount += 1
            guard let target = aspect.instance as? User else { XCTFail(); return }
            
            aspect.originalInvocation.invoke()
            
            XCTAssertNotNil(target)
            XCTAssertNotNil(target.productName)
        } as AspectBlock)
        
        user.buy(productName: "MacBook", price: 10000, count: 2, size: size)
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(user.productName, "MacBook")
    }
    
    func testAfterHookSelectorOfOneInstance() {
        var invokeCount = 0
        let size = CGSize(width: 320, height: 640)
        let userA = User()
        let userB = User()
        
        userA.unhookSelector(#selector(User.buy(productName:price:count:size:)))
        userA.hook(#selector(User.buy(productName:price:count:size:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            let target = aspect.instance as! User
            XCTAssertNotNil(target)
            XCTAssertNotNil(target.productName)
        } as AspectBlock)
        
        userA.buy(productName: "MacBook", price: 10000.78, count: 2, size: size)
        userB.buy(productName: "iPhone", price: 5000, count: 5, size: size)
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertNotNil(userA.productName)
    }
    
    func testHookCustomObjectWithBlock() {
        var invokeCount = 0
        let user = User()
        
        user.hook(#selector(User.buy(products:completion:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? User {
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
        let user = User()
        let indexPath = IndexPath(item: 5, section: 10)
        
        user.hook(#selector(User.buy(product:indexPath:error:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? User {
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
        let userA = User()
        let userB = User()
        let indexPath = IndexPath(item: 5, section: 10)
        
        userA.hook(#selector(User.buy(productName:price:count:indexPath:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            if let target = aspect.instance as? User {
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
        
        userA.buy(productName: "MacBook", price: 10000.23, count: 2, indexPath: indexPath)
        userB.buy(productName: "iPhone", price: 5000, count: 3, indexPath: IndexPath(item: 2, section: 7))
        
        XCTAssertEqual(invokeCount, 1)
        XCTAssertEqual(userA.productName, "MacBook")
        XCTAssertEqual(userA.price, 10000.23)
        XCTAssertEqual(userA.count, 2)
    }
    
    func testHookSameSelectorInDistinctClasses() {
        var invokeCatCount = 0
        var invokeDogCount = 0
        var invokeAnimalCount = 0
        let cat = Cat()
        let dog = Dog()
        let corgi = Corgi()
        
        Cat.hook(#selector(Cat.eat), position: .after, usingBlock: { aspect in
            invokeCatCount += 1
            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)
        
        Dog.hook(#selector(Dog.eat), position: .after, usingBlock: { aspect in
            invokeDogCount += 1
            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)
        
        Animal.hook(#selector(Animal.roar), position: .after, usingBlock: { aspect in
            invokeAnimalCount += 1
            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)
        
        Cat.eat()
        Dog.eat()
        
        cat.roar()
        dog.roar()
        corgi.roar()
        
        XCTAssertEqual(invokeCatCount, 1)
        XCTAssertEqual(invokeDogCount, 1)
        XCTAssertEqual(invokeAnimalCount, 3)
    }
    
    // Must hook the selector of subclass and then hook the selector of super class for the unit test
    func testHookSameSelectorDuplicated() {
        var invokeDogCount = 0
        let dog = Dog()
        let corgi = Corgi()

        Corgi.hook(#selector(Corgi.run), position: .after, usingBlock: { aspect in
            invokeDogCount += 1
            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)

        Dog.hook(#selector(Dog.run), position: .after, usingBlock: { aspect in
            invokeDogCount += 1
            XCTAssertNotNil(aspect.instance)
        } as AspectBlock)

        dog.run()
        corgi.run()

        XCTAssertEqual(invokeDogCount, 1)
    }
    
    func testHookMethodWithEnumAndBoolType() {
        var invokeCount = 0
        let userA = User()
        let userB = User()
        
        User.hook(#selector(User.login(type:needPassword:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 2)
            XCTAssertEqual(aspect.arguments.last as! Bool, true)
        } as AspectBlock)
        
        userA.hook(#selector(User.login(type:)), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 1)
            XCTAssertEqual(aspect.arguments.last as! Int, LoginType.mobile.rawValue)
        } as AspectBlock)
        
        userA.login(type: .mobile)
        userB.login(type: .email)
        userA.login(type: .mobile, needPassword: true)
        userB.login(type: .email, needPassword: true)
        
        XCTAssertEqual(invokeCount, 3)
        XCTAssertEqual(userA.loginType, LoginType.mobile)
        XCTAssertEqual(userB.loginType, LoginType.email)
    }
    
    func testHookAndUnhookSelector() {
        var invokeCount = 0
        let user = User()
        
        User.hook(#selector(User.logout), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 0)
        } as AspectBlock)
        
        user.logout()
        XCTAssertEqual(invokeCount, 1)
        
        user.unhookSelector(#selector(User.logout))
        
        user.logout()
        XCTAssertEqual(invokeCount, 1)
        
        user.hook(#selector(User.logout), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 0)
        } as AspectBlock)
        
        user.logout()
        XCTAssertEqual(invokeCount, 2)
        
        User.unhookSelector(#selector(User.logout))
    }
    
    func testHookNoImplementationSelector() {
        var invokeCount = 0
        let customer = Customer()
        
        Customer.unhookSelector(#selector(Customer.logout))
        Customer.hook(#selector(Customer.logout), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 0)
        } as AspectBlock)
        
        customer.logout()
        customer.logout()
        
        XCTAssertEqual(invokeCount, 2)
        
        Customer.unhookSelector(#selector(Customer.logout))
    }
    
    func testHookStaticMethod() {
        var invokeCount = 0
        
        User.hook(#selector(User.exit), position: .after, usingBlock: { aspect in
            invokeCount += 1
            
            XCTAssertNotNil(aspect.instance)
            XCTAssertEqual(aspect.arguments.count, 0)
        } as AspectBlock)
        
        User.exit()
        
        XCTAssertEqual(invokeCount, 1)
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
    var size: CGSize?
    var indexPath: IndexPath?
    var completion: ((Bool) -> Void)?
    var error: NSError?
    
    @objc dynamic static func exit() {}
    @objc dynamic func logout() {}
    
    @objc dynamic func login(type: LoginType) {
        loginType = type
    }
    
    @objc dynamic func login(type: LoginType, needPassword: Bool) {
        loginType = type
    }
    
    @objc dynamic func buy(productName: String, price: CGFloat, count: Int, size: CGSize) {
        self.productName = productName
        self.price = Double(exactly: price)
        self.count = count
        self.size = size
    }

    @objc dynamic func buy(productName: String, price: Double, count: Int, indexPath: IndexPath) {
        self.productName = productName
        self.price = price
        self.count = count
        self.indexPath = indexPath
    }
    
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

private class Customer: User { }

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

private class Animal: NSObject {
    
    @objc dynamic static func eat() {}
    @objc dynamic func run() {}
    @objc dynamic func roar() {}
}

private class Cat: Animal {}
private class Dog: Animal {}
private class Corgi: Dog {
    @objc dynamic override func run() {
        super.run()
    }
}
