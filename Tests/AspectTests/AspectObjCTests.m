//
//  AspectObjCTests.m
//  AspectObjCTests
//
//  Created by Kris Liu on 2019/4/1.
//  Copyright © 2022 Gravity. All rights reserved.
//

#import <XCTest/XCTest.h>
@import Aspect;

@interface AspectObjCTests : XCTestCase

@end

@implementation AspectObjCTests

- (void)testHookStaticMethod {
    __block NSUInteger invokeCount = 0;
    NSURLSessionConfiguration *conf = NSURLSessionConfiguration.defaultSessionConfiguration;
    
    [NSURLSession hookSelector:@selector(sessionWithConfiguration:) position:AspectPositionAfter usingBlock:^(AspectObject *aspect, NSURLSessionConfiguration *configuration) {
        invokeCount += 1;
        
        XCTAssertNotNil(aspect.instance);
        XCTAssertEqual(configuration, conf);
        XCTAssertEqual(aspect.arguments.firstObject, conf);
    }];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:conf];
    [session dataTaskWithURL:[NSURL new]];
    
    XCTAssertEqual(invokeCount, 1);
}

- (void)testHookInstanceMethod {
    __block NSUInteger invokeCount = 0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    
    [session hookSelector:@selector(getAllTasksWithCompletionHandler:) position:AspectPositionAfter usingBlock:^(AspectObject *aspect) {
        invokeCount += 1;
        
        XCTAssertNotNil(aspect.instance);
        XCTAssertNotNil(aspect.arguments.firstObject);
    }];
    
    [session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
        sleep(1);
        invokeCount += 1;
        XCTAssertEqual(invokeCount, 2);
    }];
    
    XCTAssertEqual(invokeCount, 1);
}

@end
