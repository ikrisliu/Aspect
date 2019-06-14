//
//  NSObject+Aspect.m
//  Aspect
//
//  Created by Kris Liu on 2019/3/9.
//  Copyright © 2019 Syzygy. All rights reserved.
//

#import "NSObject+Aspect.h"
@import ObjectiveC;
@import os.log;
@import os.lock;

#define log_debug(format, ...) __extension__({ \
    NSBundle *currentBundle = [NSBundle bundleForClass:AspectObject.self]; \
    NSString *bundleName = currentBundle.infoDictionary[@"CFBundleName"]; \
    os_log_t log = os_log_create(currentBundle.bundleIdentifier.UTF8String, bundleName.UTF8String); \
    os_log_debug(log, format, ##__VA_ARGS__); \
})

static NSString *const kAliasSelectorPrefix = @"aspect_";

#pragma mark - Block Type
#pragma mark -
typedef NS_OPTIONS(int, AspectBlockFlags) {
    AspectBlockFlagsHasCopyDisposeHelpers = (1 << 25),
    AspectBlockFlagsHasSignature          = (1 << 30)
};

typedef struct _AspectBlock {
    __unused Class isa;
    AspectBlockFlags flags;
    __unused int reserved;
    void (__unused *invoke)(struct _AspectBlock *block, ...);
    struct {
        unsigned long int reserved;
        unsigned long int size;
        // requires AspectBlockFlagsHasCopyDisposeHelpers
        void (*copy)(void *dst, const void *src);
        void (*dispose)(const void *);
        // requires AspectBlockFlagsHasSignature
        const char *signature;
        const char *layout;
    } *descriptor;
    // imported variables
} *AspectBlockRef;

static NSMethodSignature *aop_blockMethodSignature(id block)
{
    AspectBlockRef layout = (__bridge void *)block;
    if (!(layout->flags & AspectBlockFlagsHasSignature)) {
        log_debug("The block <%@> doesn't contain a type signature.", block);
        return nil;
    }
    
    void *desc = layout->descriptor;
    desc += 2 * sizeof(unsigned long int);
    if (layout->flags & AspectBlockFlagsHasCopyDisposeHelpers) {
        desc += 2 * sizeof(void *);
    }
    
    if (!desc) {
        log_debug("The block <%@> doesn't has a type signature.", block);
        return nil;
    }
    
    const char *signature = (*(const char **)desc);
    return [NSMethodSignature signatureWithObjCTypes:signature];
}

static NSMethodSignature *aop_methodSignature(id target, SEL selector)
{
    return [[target class] instanceMethodSignatureForSelector:selector] ?: [[target class] methodSignatureForSelector:selector];
}

static BOOL aop_isCompatibleBlockSignature(NSMethodSignature *blockSignature, id target, SEL selector)
{
    BOOL signaturesMatch = YES;
    NSMethodSignature *methodSignature = aop_methodSignature(target, selector);
    if (blockSignature.numberOfArguments > methodSignature.numberOfArguments) {
        signaturesMatch = NO;
    } else {
        if (blockSignature.numberOfArguments > 1) {
            const char *blockType = [blockSignature getArgumentTypeAtIndex:1];
            if (blockType[0] != '@') {
                signaturesMatch = NO;
            }
        }
        // Argument 0 is self/block, argument 1 is SEL or id<AspectObject>. We start comparing at argument 2.
        // The block can have less arguments than the method, that's ok.
        if (signaturesMatch) {
            for (NSUInteger idx = 2; idx < blockSignature.numberOfArguments; idx++) {
                const char *methodType = [methodSignature getArgumentTypeAtIndex:idx];
                const char *blockType = [blockSignature getArgumentTypeAtIndex:idx];
                // Only compare parameter, not the optional type data.
                if (!methodType || !blockType || methodType[0] != blockType[0]) {
                    signaturesMatch = NO; break;
                }
            }
        }
    }
    
    if (!signaturesMatch) {
        log_debug("Block signature <%@> doesn't match <%@>.", blockSignature, methodSignature);
        return NO;
    }
    
    return signaturesMatch;
}


#pragma mark - NSInvocation
#pragma mark -
@interface NSInvocation (AOP)

@property (nonatomic, strong, readonly) NSArray *aop_arguments;

@end

@implementation NSInvocation (AOP)

- (id)aop_argumentAtIndex:(NSUInteger)index
{
    const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
    // Skip const type qualifier.
    if (argType[0] == _C_CONST) argType++;
    
#define WRAP_AND_RETURN(type) do { type val = 0; [self getArgument:&val atIndex:(NSInteger)index]; return @(val); } while (0)
    if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing id returnObj;
        [self getArgument:&returnObj atIndex:(NSInteger)index];
        return returnObj;
    } else if (strcmp(argType, @encode(SEL)) == 0) {
        SEL selector = 0;
        [self getArgument:&selector atIndex:(NSInteger)index];
        return NSStringFromSelector(selector);
    } else if (strcmp(argType, @encode(Class)) == 0) {
        __autoreleasing Class theClass = Nil;
        [self getArgument:&theClass atIndex:(NSInteger)index];
        return theClass;
        // Using this list will box the number with the appropriate constructor, instead of the generic NSValue.
    } else if (strcmp(argType, @encode(char)) == 0) {
        WRAP_AND_RETURN(char);
    } else if (strcmp(argType, @encode(int)) == 0) {
        WRAP_AND_RETURN(int);
    } else if (strcmp(argType, @encode(short)) == 0) {
        WRAP_AND_RETURN(short);
    } else if (strcmp(argType, @encode(long)) == 0) {
        WRAP_AND_RETURN(long);
    } else if (strcmp(argType, @encode(long long)) == 0) {
        WRAP_AND_RETURN(long long);
    } else if (strcmp(argType, @encode(unsigned char)) == 0) {
        WRAP_AND_RETURN(unsigned char);
    } else if (strcmp(argType, @encode(unsigned int)) == 0) {
        WRAP_AND_RETURN(unsigned int);
    } else if (strcmp(argType, @encode(unsigned short)) == 0) {
        WRAP_AND_RETURN(unsigned short);
    } else if (strcmp(argType, @encode(unsigned long)) == 0) {
        WRAP_AND_RETURN(unsigned long);
    } else if (strcmp(argType, @encode(unsigned long long)) == 0) {
        WRAP_AND_RETURN(unsigned long long);
    } else if (strcmp(argType, @encode(float)) == 0) {
        WRAP_AND_RETURN(float);
    } else if (strcmp(argType, @encode(double)) == 0) {
        WRAP_AND_RETURN(double);
    } else if (strcmp(argType, @encode(BOOL)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(bool)) == 0) {
        WRAP_AND_RETURN(BOOL);
    } else if (strcmp(argType, @encode(char *)) == 0) {
        WRAP_AND_RETURN(const char *);
    } else if (strcmp(argType, @encode(void (^)(void))) == 0) {
        __unsafe_unretained id block = nil;
        [self getArgument:&block atIndex:(NSInteger)index];
        return [block copy];
    } else {
        NSUInteger valueSize = 0;
        NSGetSizeAndAlignment(argType, &valueSize, NULL);
        
        unsigned char valueBytes[valueSize];
        [self getArgument:valueBytes atIndex:(NSInteger)index];
        
        return [NSValue valueWithBytes:valueBytes objCType:argType];
    }
    return nil;
#undef WRAP_AND_RETURN
}

- (NSArray *)aop_arguments
{
    NSMutableArray *argumentsArray = [NSMutableArray array];
    for (NSUInteger idx = 2; idx < self.methodSignature.numberOfArguments; idx++) {
        [argumentsArray addObject:[self aop_argumentAtIndex:idx] ?: NSNull.null];
    }
    return [argumentsArray copy];
}

@end


#pragma mark - Aspect Object
#pragma mark -
@implementation AspectObject

@synthesize arguments = _arguments;

- (id)initWithInstance:(__unsafe_unretained id)instance invocation:(NSInvocation *)invocation
{
    NSCParameterAssert(instance);
    NSCParameterAssert(invocation);
    
    if (self = [super init]) {
        _instance = instance;
        _originalInvocation = invocation;
    }
    return self;
}

// Lazily evaluate arguments, boxing is expensive.
- (NSArray *)arguments
{
    if (!_arguments) {
        _arguments = self.originalInvocation.aop_arguments;
    }
    return _arguments;
}

@end


#pragma mark - Aspect Identifier
#pragma mark -
@interface AspectIdentifier : NSObject

+ (instancetype)identifierWithTarget:(id)target selector:(SEL)selector position:(AspectPosition)position block:(id)block;

- (void *)invokeWithObject:(AspectObject *)object;

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, assign) AspectPosition position;
@property (nonatomic, copy) id block;
@property (nonatomic, strong) NSMethodSignature *blockSignature;

@end

@implementation AspectIdentifier

+ (instancetype)identifierWithTarget:(id)target selector:(SEL)selector position:(AspectPosition)position block:(id)block
{
    NSMethodSignature *blockSignature = aop_blockMethodSignature(block);
    if (!aop_isCompatibleBlockSignature(blockSignature, target, selector)) {
        return nil;
    }
    
    AspectIdentifier *identifier = nil;
    if (blockSignature) {
        identifier = [AspectIdentifier new];
        identifier.target = target;
        identifier.selector = selector;
        identifier.position = position;
        identifier.block = block;
        identifier.blockSignature = blockSignature;
    }
    return identifier;
}

- (void *)invokeWithObject:(AspectObject *)object
{
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:self.blockSignature];
    NSInvocation *originalInvocation = object.originalInvocation;
    NSUInteger numberOfArguments = self.blockSignature.numberOfArguments;
    
    // Be extra paranoid. We already check that on hook registration.
    if (numberOfArguments > originalInvocation.methodSignature.numberOfArguments) {
        return NULL;
    }
    
    // The `self` of the block will be the AspectObject. Optional.
    if (numberOfArguments > 1) {
        [blockInvocation setArgument:&object atIndex:1];
    }
    
    void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < numberOfArguments; idx++) {
        const char *type = [originalInvocation.methodSignature getArgumentTypeAtIndex:idx];
        NSUInteger argSize;
        NSGetSizeAndAlignment(type, &argSize, NULL);
        
        if (!(argBuf = reallocf(argBuf, argSize))) return NULL;
        
        [originalInvocation getArgument:argBuf atIndex:idx];
        [blockInvocation setArgument:argBuf atIndex:idx];
    }
    
    [blockInvocation invokeWithTarget:self.block];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    
    if (strcmp(blockInvocation.methodSignature.methodReturnType, @encode(void)) == 0) {
        return NULL;
    }
    
    void *result;
    [blockInvocation getReturnValue:&result];
    return result;
}

@end


#pragma mark - Hook
#pragma mark -
@interface NSObject ()

@property(nonatomic, strong) NSMutableDictionary<NSString *, AspectIdentifier*> *aop_blocks;

@end

@implementation NSObject (Aspect)

- (NSMutableDictionary<NSString *,id> *)aop_blocks
{
    return objc_getAssociatedObject(self, @selector(aop_blocks));
}

- (void)setAop_blocks:(NSMutableDictionary<NSString *,AspectIdentifier *> *)aop_blocks
{
    objc_setAssociatedObject(self, @selector(aop_blocks), aop_blocks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (BOOL)hookSelector:(SEL)selector position:(AspectPosition)position usingBlock:(id)block;
{
    return aop_hookSelector(self, selector, position, block);
}

- (BOOL)hookSelector:(SEL)selector position:(AspectPosition)position usingBlock:(id)block;
{
    return aop_hookSelector(self, selector, position, block);
}

static BOOL aop_hookSelector(id self, SEL selector, AspectPosition position, id block)
{
    if (!aop_isSelectorAllowedHook(self, selector)) {
        NSCAssert(false, @"Disallow hook selector <%@>.", NSStringFromSelector(selector));
        return NO;
    }
    
    __block BOOL isSuccess = YES;
    
    aop_performLock(^{
        Method method = class_getInstanceMethod([self class], selector);
        Class clazz = method ? [self class] : object_getClass([self class]);
        method = method ?: class_getClassMethod([self class], selector);
        
        if (method == NULL) {
            log_debug("Hooked selector <%@> doesn't exist in class <%@>", NSStringFromSelector(selector), NSStringFromClass(clazz));
            isSuccess = NO; return;
        }
        
        Method aliasMethod = class_getInstanceMethod(clazz, aop_aliasForSelector(selector));
        
        // If alias method does exist and is not empty implementation which means it is unhooked.
        if (aliasMethod && method_getImplementation(aliasMethod) != (IMP)aop_emptyImplementationSelector) {
            log_debug("The selector <%@> in class <%@> has been hooked, disallow duplicate hook.", NSStringFromSelector(selector), NSStringFromClass(clazz));
            isSuccess = YES; return;
        }
        
        IMP imp = method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);
        
        // If add method failed, it means the alias method already exist in current class, just need set a new imp to it.
        if (!class_addMethod(clazz, aop_aliasForSelector(selector), imp, types)) {
            method_setImplementation(aliasMethod, imp);
        }
        
        if (![self aop_blocks]) {
            [self setAop_blocks:[NSMutableDictionary dictionary]];
        }
        [self aop_blocks][NSStringFromSelector(selector)] = [AspectIdentifier identifierWithTarget:self selector:selector position:position block:block];
        
        class_replaceMethod(clazz, @selector(forwardInvocation:), (IMP)aspect_forwardInvocation, "v@:@");
        class_replaceMethod(clazz, selector, aspect_msgForwardIMP(clazz, selector), types);
    });
    
    return isSuccess;
}

static BOOL aop_isSelectorAllowedHook(NSObject *self, SEL selector)
{
    return ![@[@"retain", @"release", @"autorelease", @"forwardInvocation:"] containsObject:NSStringFromSelector(selector)];
}

static void aspect_forwardInvocation(id self, SEL selector, NSInvocation *invocation) {
    SEL originalSelector = invocation.selector;
    invocation.selector = aop_aliasForSelector(originalSelector);
    
    NSString *key = NSStringFromSelector(originalSelector);
    AspectIdentifier *identifier = [self aop_blocks][key] ?: [[self class] aop_blocks][key];
    
    // Check if the selector hooked by super class
    if (identifier == nil) {
        Class class = object_getClass(self);
        while (identifier == nil) {
            Class superClass = class_getSuperclass(class);
            if (superClass == class) { break; }
            
            identifier = [class aop_blocks][key];
            class = superClass;
        }
    }
    
    // It means this instance's selector is not hooked
    if (identifier == nil) {
        aop_invokeOriginalInvocation(invocation);
        return;
    }
    
    switch (identifier.position) {
        case AspectPositionAfter:
            aop_invokeOriginalInvocation(invocation);
            aop_invokeHookedBlock(self, identifier, invocation);
            break;
            
        case AspectPositionBefore:
            aop_invokeHookedBlock(self, identifier, invocation);
            aop_invokeOriginalInvocation(invocation);
            break;
            
        case AspectPositionInstead:
            aop_invokeHookedBlock(self, identifier, invocation);
            break;
    }
}

static IMP aspect_msgForwardIMP(Class clazz, SEL selector) {
    IMP msgForwardIMP = _objc_msgForward;
#if !defined(__arm64__)
    // As an ugly internal runtime implementation detail in the 32bit runtime, we need to determine of the method we hook returns a struct or anything larger than id.
    // https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
    // https://github.com/ReactiveCocoa/ReactiveCocoa/issues/783
    // http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf (Section 5.4)
    Method method = class_getInstanceMethod(clazz, selector);
    const char *encoding = method_getTypeEncoding(method);
    BOOL methodReturnsStructValue = encoding[0] == _C_STRUCT_B;
    if (methodReturnsStructValue) {
        @try {
            NSUInteger valueSize = 0;
            NSGetSizeAndAlignment(encoding, &valueSize, NULL);
            
            if (valueSize == 1 || valueSize == 2 || valueSize == 4 || valueSize == 8) {
                methodReturnsStructValue = NO;
            }
        } @catch (NSException *e) {}
    }
    if (methodReturnsStructValue) {
        msgForwardIMP = (IMP)_objc_msgForward_stret;
    }
#endif
    return msgForwardIMP;
}

static void aop_performLock(dispatch_block_t block)
{
    os_unfair_lock aspect_lock = OS_UNFAIR_LOCK_INIT;
    os_unfair_lock_lock(&aspect_lock);
    block();
    os_unfair_lock_unlock(&aspect_lock);
}

static void* aop_invokeOriginalInvocation(NSInvocation *invocation)
{
    [invocation invoke];
    
    if (strcmp(invocation.methodSignature.methodReturnType, @encode(void)) == 0) {
        return NULL;
    }
    
    void *result;
    [invocation getReturnValue:&result];
    return result;
}

static void* aop_invokeHookedBlock(id self, AspectIdentifier *identifier, NSInvocation *invocation)
{
    AspectObject *object = [[AspectObject alloc] initWithInstance:self invocation:invocation];
    return [identifier invokeWithObject:object];
}

#pragma mark - Unhook
#pragma mark -
+ (BOOL)unhookSelector:(SEL)selector
{
    return aop_unhookSelector(self, selector);
}

- (BOOL)unhookSelector:(SEL)selector
{
    return aop_unhookSelector(self, selector);
}

static SEL aop_aliasForSelector(SEL selector)
{
    return NSSelectorFromString([kAliasSelectorPrefix stringByAppendingString:NSStringFromSelector(selector)]);
}

static void aop_emptyImplementationSelector(id self, SEL _cmd) { }

static BOOL aop_unhookSelector(id self, SEL selector)
{
    __block BOOL isSuccess = YES;
    
    aop_performLock(^{
        SEL aliasSelector = aop_aliasForSelector(selector);
        Method aliasMethod = class_getInstanceMethod([self class], aliasSelector);
        aliasMethod = aliasMethod ?: class_getClassMethod([self class], aliasSelector);
        
        if (aliasMethod == NULL) {
            log_debug("No hook for selector <%@> in class <%@>", NSStringFromSelector(selector), NSStringFromClass([self class]));
            isSuccess = NO; return;
        }
        
        Method method = class_getInstanceMethod([self class], selector);
        method = method ?: class_getClassMethod([self class], selector);
        
        IMP originalIMP = method_getImplementation(aliasMethod);
        method_setImplementation(method, originalIMP);
        method_setImplementation(aliasMethod, (IMP)aop_emptyImplementationSelector);
        
        [[self aop_blocks] removeObjectForKey:NSStringFromSelector(selector)];
        
        if ([self aop_blocks].count == 0) {
            [self setAop_blocks:nil];
        }
    });
    
    return YES;
}

@end
