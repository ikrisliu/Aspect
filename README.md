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

```swift
NSObject.hookSelector(with: #selector(doesNotRecognizeSelector(_:)), position: .instead, usingBlock: { aspect in
    print("Do something in this block")
} as AspectBlock)

// Hook method "viewDidAppear" of all UIViewController's instances
UIViewController.hookSelector(with: #selector(UIViewController.viewDidAppear(_:)), position: .after, usingBlock: { aspect in
    print("Do something in this block")
} as AspectBlock)

// Hook only viewController's instance "viewDidLoad"
let viewController = UIViewController()
viewController.hookSelector(with: #selector(UIViewController.viewDidLoad), position: .before, usingBlock: { aspect in
    print("Do something in this block")
} as AspectBlock)
```

```objective-c
[NSURLSession hookSelectorWith:@selector(sessionWithConfiguration:) position:AspectPositionBefore usingBlock:^{
    NSLog(@"Do something in this block")
}];

NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
[session hookSelectorWith:@selector(getAllTasksWithCompletionHandler:) position:AspectPositionAfter usingBlock:^{
    NSLog(@"Do something in this block");
}];
```

## Limitation
### macOS
You can hook any selector which has any argument count without limitation. But **struct and union** type are not supported.

### iOS/tvOS/watchOS
Since ARM64 varargs routines changed calling conventions, we can only use work around solution to limit method's argument count with **6**, you can change source code to modify the count if needed. For method's argument type, it doesn't support these types that are not NSObject: 
**float, double, struct, union** and so on.

Some help links about these limitations:   
[Apple Forum](https://forums.developer.apple.com/thread/38470)  
[Apple Developer Documentation](https://developer.apple.com/documentation/uikit/core_app/updating_your_app_from_32-bit_to_64-bit_architecture/managing_functions_and_function_pointers)

## Reference

Thanks for [Aspects](https://github.com/steipete/Aspects) which developed by [@steipete](http://twitter.com/steipete) in GitHub. I referred some codes from this repository.

## Need Help

If some developer has solution to solve these limitations, please contact to me by [@iKrisLiu](https://twitter.com/iKrisLiu) or <ikris.liu@gmail.com>
