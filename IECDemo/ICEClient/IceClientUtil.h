//
//  IceClientUtil.h
//  test
//
//  Created by 邓燎燕 on 15/12/8.
//  Copyright © 2015年 邓燎燕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/Ice.h>

@protocol ICECommunicator;

typedef void (^dispatch_block)(void);

@interface IceClientUtil : NSObject

+ (id<ICECommunicator>) getICECommunicator;

+ (void) closeCommunicator:(BOOL)removeServiceCache;

+ (id<ICEObjectPrx>) getServicePrx:(NSString*)serviceName class:(Class)serviceCls ;

+ (void)serviceAsync:(dispatch_block)block;

@end
