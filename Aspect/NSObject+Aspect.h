//
//  NSObject+Aspect.h
//  Aspect
//
//  Created by Kris Liu on 2019/3/9.
//  Copyright © 2019 Syzygy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AspectPosition) {
    AspectPositionAfter   = 0,  /// Called after the original implementation. (default)
    AspectPositionBefore  = 1,  /// Called before the original implementation.
    AspectPositionInstead = 2,  /// Will replace the original implementation.
};

@interface AspectObject : NSObject

/// The instance that is currently hooked.
@property (nonatomic, unsafe_unretained, readonly) id instance;

/// The original invocation of the hooked method.
@property (nonatomic, strong, readonly) NSInvocation *originalInvocation;

/// All method arguments, boxed. This is lazily evaluated.
@property (nonatomic, strong, readonly) NSArray *arguments;

@end


/// NOTE: Disallow hook a method and super method at the same time.
/// (e.g. ViewController : UIViewController)
/// DO NOT hook ViewController.viewDidLoad and UIViewController.viewDidLoad at the same time
@interface NSObject (Aspect)

+ (BOOL)hookSelector:(SEL)selector position:(AspectPosition)position usingBlock:(id)block;
- (BOOL)hookSelector:(SEL)selector position:(AspectPosition)position usingBlock:(id)block;

+ (BOOL)unhookSelector:(SEL)selector;
- (BOOL)unhookSelector:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
