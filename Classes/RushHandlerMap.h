//
//  RushHandlerMap.h
//  RushHandler
//
//  Created by AOKI Yuuto on 13/01/08.
//  Copyright (c) 2013 Limbate All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RushHandlerMap : NSObject
+ (NSDictionary *)conformedHandlerProtocolInformations;
- (id)handlerWithName:(NSString *)handlerName;
- (void)setHandler:(id)handler forName:(NSString *)handlerName;
- (void)copyHandlersFromHandlerMap:(RushHandlerMap *)HandlerMap;
@end