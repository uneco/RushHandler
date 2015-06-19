//
//  RushHandlerMap.m
//  RushHandler
//
//  Created by AOKI Yuuto on 13/01/08.
//  Copyright (c) 2013 Limbate All rights reserved.
//

#import "RushHandlerProtocol.h"
#import "RushHandlerMap.h"
#import <objc/runtime.h>

@interface RushHandlerMap ()
@property (nonatomic, retain) NSMutableDictionary *handlerStore;
@end

@implementation RushHandlerMap

- (NSMutableDictionary *)handlerStore
{
    if (_handlerStore == nil) {
        _handlerStore = [NSMutableDictionary dictionary];
    }
    return _handlerStore;
}

+ (NSDictionary *)conformedHandlerProtocolInformations
{
    NSMutableDictionary *protocolInformations = [NSMutableDictionary dictionary];
    
    unsigned int numberOfProtocols;
    Protocol *__unsafe_unretained *protocols = class_copyProtocolList(self, &numberOfProtocols);
    for (unsigned int index = 0; index < numberOfProtocols; index++) {
        Protocol *protocol = protocols[index];
        
        if (! protocol_conformsToProtocol(protocol, @protocol(RushHandler))) {
            continue;
        }
        
        const char *protocolName = protocol_getName(protocol);
        NSString *protocolNameObject = [NSString stringWithCString:protocolName encoding:NSASCIIStringEncoding];
        
        NSMutableArray *propertyNameObjects = [NSMutableArray array];
        unsigned int numberOfProperties;
        objc_property_t *properties = protocol_copyPropertyList(protocol, &numberOfProperties);
        for (unsigned int index = 0; index < numberOfProperties; index++) {
            objc_property_t property = properties[index];
            const char *propertyName = property_getName(property);
            NSString *propertyNameObject = [NSString stringWithCString:propertyName encoding:NSASCIIStringEncoding];
            [propertyNameObjects addObject:propertyNameObject];
        }
        free(properties);
        protocolInformations[protocolNameObject] = propertyNameObjects;
    }
    free(protocols);
    
    return protocolInformations.copy;
}

- (void)copyHandlersFromHandlerMap:(RushHandlerMap *)HandlerMap
{
    _handlerStore = HandlerMap.handlerStore.mutableCopy;
}

- (id)handlerWithName:(NSString *)handlerName
{
    id handler = [self.handlerStore objectForKey:handlerName];
    if (handler == nil) {
        return ^{};
    }
    return handler;
}

- (void)setHandler:(id)handler forName:(NSString *)handlerName
{
    id copiedBlock = (__bridge id)Block_copy((__bridge void *)handler);
    [self.handlerStore setObject:copiedBlock forKey:handlerName];
    Block_release((__bridge void *)copiedBlock);
}

/* ------------------------------------------------------------------------------------------------------------------ */
#pragma mark -
#pragma mark handler method addition

+ (NSString *)setterNameWithGetterName:(NSString *)getterName
{
    return [NSString stringWithFormat:@"set%@%@:", [getterName substringToIndex:1].uppercaseString, [getterName substringFromIndex:1]];
}

+ (NSString *)getterNameWithSetterName:(NSString *)setterName
{
    return [NSString stringWithFormat:@"%@%@", [setterName substringWithRange:NSMakeRange(3, 1)].lowercaseString, [setterName substringFromIndex:4]];
}

+ (void)generateHandlerGetter:(NSString *)name
{
    SEL selector = NSSelectorFromString(name);
    if (! [self respondsToSelector:selector]) {
        class_addMethod(self,
                        selector,
                        [self instanceMethodForSelector:@selector(handlerGetterTemplate)],
                        "@@:");
    }
}

+ (void)generateHandlerSetter:(NSString *)name
{        SEL selector = NSSelectorFromString([self setterNameWithGetterName:name]);
    if (! [self respondsToSelector:selector]) {
        class_addMethod([self class],
                        selector,
                        [self instanceMethodForSelector:@selector(handlerSetterTemplate:)],
                        "v@:@");
    }
}

- (id)handlerGetterTemplate
{
    return [self handlerWithName:NSStringFromSelector(_cmd)];
}

- (void)handlerSetterTemplate:(id)obj
{
    NSInteger prefixLength = @"set".length;
    NSString *selectorString = NSStringFromSelector(_cmd);
    
    NSRange nameInitialRange        = NSMakeRange(prefixLength, 1);
    NSRange nameWithoutInitialRange = NSMakeRange(prefixLength + 1, selectorString.length - 5);
    
    NSString *name = [NSString stringWithFormat:@"%@%@",
                      [[selectorString substringWithRange:nameInitialRange] lowercaseString],
                      [selectorString substringWithRange:nameWithoutInitialRange]];
    
    if (obj == nil) {
        [self.handlerStore removeObjectForKey:name];
    } else {
        [self setHandler:obj forName:name];
    }
}

- (BOOL)hasSetterForName:(NSString *)name
{
    return [self respondsToSelector:NSSelectorFromString([self.class setterNameWithGetterName:name])];
}

- (BOOL)hasGetterForName:(NSString *)name
{
    return [self respondsToSelector:NSSelectorFromString(name)];
}

- (id)init
{
    self = [super init];
    if (self) {
        for (NSArray *properties in [self.class conformedHandlerProtocolInformations].allValues) {
            for (NSString *propertyName in properties) {
                if (! [self hasGetterForName:propertyName]) {
                    [self.class generateHandlerGetter:propertyName];
                }
                if (! [self hasSetterForName:propertyName]) {
                    [self.class generateHandlerSetter:propertyName];
                }
            }
        }
    }
    return self;
}

@end
