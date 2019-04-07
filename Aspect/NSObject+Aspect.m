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
    BOOL isMetaClass = class_isMetaClass(object_getClass(target));
    NSMethodSignature *signature = isMetaClass ? [[target class] methodSignatureForSelector:selector] : [[target class] instanceMethodSignatureForSelector:selector];
    return signature;
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

+ (instancetype)identifierWithTarget:(id)target selector:(SEL)selector block:(id)block;

- (void *)invokeWithObject:(AspectObject *)object;

@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, strong) id block;
@property (nonatomic, strong) NSMethodSignature *blockSignature;

@end

@implementation AspectIdentifier

+ (instancetype)identifierWithTarget:(id)target selector:(SEL)selector block:(id)block
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


#pragma mark - Aspect Hook
#pragma mark -
@implementation NSObject (Aspect)

+ (BOOL)hookSelector:(SEL)selector position:(AspectPosition)position usingBlock:(id)block;
{
    return aop_hookSelector(self, selector, position, block);
}

- (BOOL)hookSelector:(SEL)selector position:(AspectPosition)position usingBlock:(id)block;
{
    return aop_hookSelector(self, selector, position, block);
}

+ (BOOL)unhookSelector:(SEL)selector
{
    return aop_unhookSelector(self, selector);
}

- (BOOL)unhookSelector:(SEL)selector
{
    return aop_unhookSelector(self, selector);
}

static BOOL aop_hookSelector(id self, SEL selector, AspectPosition position, id block)
{
#if TARGET_OS_IPHONE
    // On 64-bit ARM varargs routines use different calling conventions from standard routines.
    // Thus implementing a non-varargs method with a varargs block is simply not feasible.
    // This limitation is not just for 64-bit ARM. There are similar differences between varargs
    // and non-varargs calling conventions on other runtime architectures as well.
    // It’s just that those differences general occur at the `edges` of the runtime architecture.
    // So we can only use below work around solution to limit the argument count for ARM64.
    // https://developer.apple.com/documentation/uikit/core_app/updating_your_app_from_32-bit_to_64-bit_architecture/managing_functions_and_function_pointers
    IMP blockIMP = imp_implementationWithBlock(^(id target, va_list arg1, va_list arg2, va_list arg3, va_list arg4, va_list arg5, va_list arg6) {
        SEL aliasSelector = aop_aliasForSelector(selector);
        NSInvocation *originalInvocation = aop_originalInvocation(target, aliasSelector, aop_fixedArguments(arg1, arg2, arg3, arg4, arg5, arg6));
#else
    IMP blockIMP = imp_implementationWithBlock(^(id target, ...) {
        va_list arguments;
        va_start(arguments, target);
        
        SEL originalSelector = aop_aliasForSelector(selector);
        NSInvocation *originalInvocation = aop_originalInvocation(target, originalSelector, arguments);
        
        va_end(arguments);
#endif
        
        if (self != [self class] && self != target) {
            return aop_invokeOriginalInvocation(originalInvocation);
        }
        
        void *result;
        
        switch (position) {
            case AspectPositionAfter:
                result = aop_invokeOriginalInvocation(originalInvocation);
                aop_invokeHookedBlock(target, selector, block, originalInvocation);
                break;
                
            case AspectPositionBefore:
                aop_invokeHookedBlock(target, selector, block, originalInvocation);
                result = aop_invokeOriginalInvocation(originalInvocation);
                break;
                
            case AspectPositionInstead:
                result = aop_invokeHookedBlock(target, selector, block, originalInvocation);
                break;
        }
        
        return result;
    });
    
    Method method = class_getInstanceMethod([self class], selector);
    Class clazz = method ? [self class] : object_getClass([self class]);
    method = method ?: class_getClassMethod([self class], selector);
    
    if (method == NULL) {
        log_debug("Hooked selector <%@> doesn't exist in class <%@>", NSStringFromSelector(selector), NSStringFromClass(clazz));
        return NO;
    }
        
    Method aliasMethod = class_getInstanceMethod(clazz, aop_aliasForSelector(selector));
    
    // If alias method does exist and is not empty implementation which means it is unhooked.
    if (aliasMethod && method_getImplementation(aliasMethod) != (IMP)aop_emptyImplementationSelector) {
        log_debug("The selector <%@> in class <%@> has been hooked, disallow duplicate hook.", NSStringFromSelector(selector), NSStringFromClass(clazz));
        return YES;
    }
    
    IMP imp = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    
    // If add method success, it means the method does not exist in current class, it exists in super class.
    // We need add a override method and call its super method for hooking.
    if (class_addMethod(clazz, selector, imp, types)) {
        method = aop_addOverrideMethodAndHook(clazz, selector, types);
    } else {
        if (!class_addMethod(clazz, aop_aliasForSelector(selector), imp, types)) {
            method_setImplementation(aliasMethod, imp);
        }
    }
    
    method_setImplementation(method, blockIMP);
    return YES;
}

static Method aop_addOverrideMethodAndHook(Class clazz, SEL selector, const char *types)
{
#if TARGET_OS_IPHONE
    IMP blockIMP = imp_implementationWithBlock(^(id target, va_list arg1, va_list arg2, va_list arg3, va_list arg4, va_list arg5, va_list arg6) {
        NSInvocation *invocation = aop_originalInvocation(target, selector, aop_fixedArguments(arg1, arg2, arg3, arg4, arg5, arg6));
        return aop_invokeOriginalInvocation(invocation);
    });
#else
    IMP blockIMP = imp_implementationWithBlock(^(id target, ...) {
        va_list arguments;
        va_start(arguments, target);
        
        NSInvocation *invocation = aop_originalInvocation(target, selector, arguments);
        
        va_end(arguments);
        
        return aop_invokeOriginalInvocation(invocation);
    });
#endif
    
    Method method = class_getInstanceMethod(clazz, selector);
    class_addMethod(clazz, aop_aliasForSelector(selector), method_getImplementation(method), types);
    method_setImplementation(method, blockIMP);
    
    return method;
}

#if TARGET_OS_IPHONE
static NSArray<NSValue *> *aop_fixedArguments(va_list arg1, va_list arg2, va_list arg3, va_list arg4, va_list arg5, va_list arg6)
{
    return @[[NSValue valueWithPointer:arg1], [NSValue valueWithPointer:arg2], [NSValue valueWithPointer:arg3],
             [NSValue valueWithPointer:arg4], [NSValue valueWithPointer:arg5], [NSValue valueWithPointer:arg6]];
}
                                           
static NSInvocation *aop_originalInvocation(id target, SEL selector, NSArray<NSValue *> *arguments)
{
    NSMethodSignature *signature = aop_methodSignature(target, selector);
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    
    // Sometimes the target's memory may be released that lead crash when call instance hook method, need call below method to retain it.
    [invocation retainArguments];
    
    invocation.target = target;
    invocation.selector = selector;
    
    // Excludes the first and second arguement
    NSCAssert(signature.numberOfArguments - 2 <= arguments.count, @"The hooked selector %@ parameter count cannot great than %tu.", NSStringFromSelector(selector), arguments.count);
    
    for (int idx = 2; idx < signature.numberOfArguments; idx++) {
        const char *argt = [signature getArgumentTypeAtIndex:idx];
        int argIdx = idx - 2;
        
        if (strcmp(argt, @encode(id)) == 0) {
            void *argv = arguments[argIdx].pointerValue;
            [invocation setArgument:&argv atIndex:idx];
        } else if (strcmp(argt, @encode(BOOL)) == 0) {
            BOOL argv = (BOOL)arguments[argIdx].pointerValue;
            [invocation setArgument:&argv atIndex:idx];
        } else if (argt[0] == _C_PTR) {
            void *argv = arguments[argIdx].pointerValue;
            [invocation setArgument:&argv atIndex:idx];
        } else if (strcmp(argt, @encode(SEL)) == 0) {
            SEL argv = (SEL)arguments[argIdx].pointerValue;
            [invocation setArgument:&argv atIndex:idx];
        } else if (strcmp(argt, @encode(Class)) == 0) {
            Class argv = (Class)arguments[argIdx].pointerValue;
            [invocation setArgument:&argv atIndex:idx];
        } else if (strcmp(argt, @encode(void (^)(void))) == 0) {
            id argv = (id)arguments[argIdx].pointerValue;
            id copiedVal = [argv copy];
            [invocation setArgument:&copiedVal atIndex:idx];
        } else if (strcmp(argt, @encode(int)) == 0 || strcmp(argt, @encode(short)) == 0 || strcmp(argt, @encode(char)) == 0 || strcmp(argt, @encode(BOOL)) == 0 ||
                   strcmp(argt, @encode(unsigned int)) == 0 || strcmp(argt, @encode(unsigned short)) == 0 || strcmp(argt, @encode(unsigned char)) == 0 ||
                   strcmp(argt, @encode(long)) == 0 || strcmp(argt, @encode(unsigned long)) == 0 || strcmp(argt, @encode(unsigned long long)) == 0) {
            void *argv = arguments[argIdx].pointerValue;
            [invocation setArgument:&argv atIndex:idx];
        } else {
            NSCAssert(NO, @"The hooked selector %@ parameters cannot have primitive type <%s>.", NSStringFromSelector(selector), argt);
        }
    }
    
    return invocation;
}

#else

static NSInvocation *aop_originalInvocation(id target, SEL selector, va_list arguments)
{
    NSMethodSignature *signature = aop_methodSignature(target, selector);
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;
    
    for (int idx = 2; idx < signature.numberOfArguments; idx++) {
        const char *argtType = [signature getArgumentTypeAtIndex:idx];
        aop_setupArgument(arguments, argtType, invocation, idx);
    }
    
    return invocation;
}
                                           
static void aop_setupArgument(va_list arguments, const char *argt, NSInvocation *invocation, NSInteger idx)
{
    if (strcmp(argt, @encode(int)) == 0 || strcmp(argt, @encode(short)) == 0 || strcmp(argt, @encode(char)) == 0 || strcmp(argt, @encode(BOOL)) == 0 || strcmp(argt, @encode(bool)) == 0) {
        int argv = va_arg(arguments, int);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(long)) == 0) {
        long argv = va_arg(arguments, long);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(long long)) == 0) {
        long long argv = va_arg(arguments, long long);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(unsigned int)) == 0 || strcmp(argt, @encode(unsigned short)) == 0 || strcmp(argt, @encode(unsigned char)) == 0) {
        unsigned int argv = va_arg(arguments, unsigned int);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(unsigned long)) == 0) {
        unsigned long argv = va_arg(arguments, unsigned long);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(unsigned long long)) == 0) {
        unsigned long long argv = va_arg(arguments, unsigned long long);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(double)) == 0 || strcmp(argt, @encode(float)) == 0) {
        double argv = va_arg(arguments, double);
        [invocation setArgument:&argv atIndex:idx];
    } else if (argt[0] == _C_PTR) {
        void * argv = va_arg(arguments, void *);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(SEL)) == 0) {
        SEL argv = va_arg(arguments, SEL);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(Class)) == 0) {
        Class argv = va_arg(arguments, Class);
        [invocation setArgument:&argv atIndex:idx];
    } else if (strcmp(argt, @encode(void (^)(void))) == 0) {
        id argv = va_arg(arguments, id);
        id copiedVal = [argv copy];
        [invocation setArgument:&copiedVal atIndex:idx];
    } else if (strcmp(argt, @encode(id)) == 0) {
        id argv = va_arg(arguments, id);
        [invocation setArgument:&argv atIndex:idx];
    } else {
        NSCAssert(NO, @"The hooked selector parameters cannot have struct/union type <%s>.", argt);
    }
}
#endif

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

static void* aop_invokeHookedBlock(id self, SEL selector, id block, NSInvocation *invocation)
{
    AspectObject *object = [[AspectObject alloc] initWithInstance:self invocation:invocation];
    AspectIdentifier *identifier = [AspectIdentifier identifierWithTarget:self selector:selector block:block];
    return [identifier invokeWithObject:object];
}

static SEL aop_aliasForSelector(SEL selector)
{
    return NSSelectorFromString([kAliasSelectorPrefix stringByAppendingString:NSStringFromSelector(selector)]);
}
                                               
static void aop_emptyImplementationSelector(id self, SEL _cmd) { }

static BOOL aop_unhookSelector(id self, SEL selector)
{
    SEL aliasSelector = aop_aliasForSelector(selector);
    Method aliasMethod = class_getInstanceMethod([self class], aliasSelector);
    aliasMethod = aliasMethod ?: class_getClassMethod([self class], aliasSelector);
    
    if (aliasMethod == NULL) {
        log_debug("No hook for selector <%@> in class <%@>", NSStringFromSelector(selector), NSStringFromClass([self class]));
        return NO;
    }
    
    Method method = class_getInstanceMethod([self class], selector);
    method = method ?: class_getClassMethod([self class], selector);
    
    IMP originalIMP = method_getImplementation(aliasMethod);
    method_setImplementation(method, originalIMP);
    
    method_setImplementation(aliasMethod, (IMP)aop_emptyImplementationSelector);
    
    return YES;
}

@end
