# Aspect

[![badge-version](https://img.shields.io/cocoapods/v/Aspect.svg?label=version)](https://github.com/iKrisLiu/Aspect/releases)
![badge-pms](https://img.shields.io/badge/languages-Swift|ObjC-orange.svg)
![badge-languages](https://img.shields.io/badge/supports-Carthage|CocoaPods|SwiftPM-green.svg)
![badge-platforms](https://img.shields.io/cocoapods/p/Aspect.svg?style=flat)

Aspect Oriented Programming in Objective-C and Swift. (For swift, the method must have `@objc dynamic` prefix keyword)


## Features
- Hook any objective-c instance/class method
- Hook methods with same name in different classes

## Installation
### Carthage
[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks. To integrate Aspect into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "iKrisLiu/Aspect" ~> 1.0
```

### CocoaPods
[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. To integrate Aspect into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'Aspect', '~> 1.0'
```

### Swift Package Manager
[Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. To integrate Aspect into your Xcode project, specify it in your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/iKrisLiu/Aspect", from: "1.0.0")
]
```

## Usage

Aspect hooks will add a block of code **after/before/instead** the current `selector`

### Swift

```swift
// Hook method "viewDidAppear" of all UIViewController's instances
UIViewController.hook(#selector(UIViewController.viewDidAppear(_:)), position: .after, usingBlock: { aspect, animated in
    print("Do something in this block")
} as @convention(block) (AspectObject, Bool) -> Void)

// Hook only viewController's instance "viewDidLoad"
let viewController = UIViewController()
viewController.hook(#selector(UIViewController.viewDidLoad), position: .before, usingBlock: { aspect in
    print("Do something in this block")
} as AspectBlock)

NSObject.hook(#selector(doesNotRecognizeSelector(_:)), position: .instead, usingBlock: { aspect in
    print("Do something in this block")
} as AspectBlock)

// Unhook selector
NSObject.unhookSelector(#selector(doesNotRecognizeSelector(_:)))
```

### Objective-C
```objective-c
[NSURLSession hookSelector:@selector(sessionWithConfiguration:) position:AspectPositionBefore usingBlock:^(AspectObject *aspect, NSURLSessionConfiguration *configuration){
    NSLog(@"Do something in this block")
}];

NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
[session hookSelector:@selector(getAllTasksWithCompletionHandler:) position:AspectPositionAfter usingBlock:^(AspectObject *aspect){
    NSLog(@"Do something in this block");
}];

[NSURLSession unhookSelector:@selector(sessionWithConfiguration:)];
```

## Reference

Thanks for [Aspects](https://github.com/steipete/Aspects) which developed by [@steipete](http://twitter.com/steipete) in GitHub. I referred some codes from his repository.
