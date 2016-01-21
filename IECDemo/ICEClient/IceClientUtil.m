//
//  IceClientUtil.m
//  test
//
//  Created by 邓燎燕 on 15/12/8.
//  Copyright © 2015年 邓燎燕. All rights reserved.
//

#import "IceClientUtil.h"

const static NSString * locatorKey = @"Ice.Locator";
static NSString * iceLocatorValue;
static id<ICECommunicator> communicator;  //Ice连接器
static NSMutableDictionary * cls2PrxMap;
static UInt64 lastAccessTimestamp;
static int idleTimeOutSeconds;  // 超时
static NSThread *monitorThread;
static BOOL stoped;

@interface IceClientUtil ()

@end

@implementation IceClientUtil

/**
 *  初始化ICE连接器
 *
 *  @return ICECommunicator
 */
+ (id<ICECommunicator>) getICECommunicator{
    if (communicator == nil) {
        @synchronized(@"communicator"){
            if (iceLocatorValue == nil) {
                NSString * plistPath = [[ NSBundle mainBundle] pathForResource:@"iceClient" ofType:@"plist"];
                NSDictionary * plist = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
                iceLocatorValue = [plist objectForKey:locatorKey];
                idleTimeOutSeconds = [[plist objectForKey:@"idleTimeOutSeconds"] intValue];
                NSLog(@"Ice client`s locator is %@ proxy cache time out seconds :%d",iceLocatorValue,idleTimeOutSeconds);
            }
            
            ICEInitializationData* initData = [ICEInitializationData initializationData];
            initData.properties = [ICEUtil createProperties];
            [initData.properties setProperty:@"Ice.Default.Locator" value:iceLocatorValue];
            initData.dispatcher = ^(id<ICEDispatcherCall> call, id<ICEConnection> con)
            {
                dispatch_sync(dispatch_get_main_queue(), ^ { [call run]; });
            };
            //NSAssert(communicator == nil, @"communicator == nil");
            communicator = [ICEUtil createCommunicator:initData];
            [IceClientUtil createMonitoerThread];
        }
    }
    lastAccessTimestamp = [[NSDate date] timeIntervalSince1970]*1000;
    return communicator;
}

/**
 *  释放ICE连接器
 *
 *  @param removeServiceCache
 */
+ (void) closeCommunicator:(BOOL)removeServiceCache{
    @synchronized(@"communicator"){
        if(communicator != nil){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
                if (communicator != nil) {
                    [IceClientUtil safeShutdown];
                    stoped = YES;
                    if(removeServiceCache && cls2PrxMap!=nil && [cls2PrxMap count]!=0){
                        [cls2PrxMap removeAllObjects];
                    }
                }
            });
        }
    }
}

+(void) safeShutdown{
    @try{
        [communicator shutdown];
    }
    @catch(ICEException* ex)
    {
    }
    @finally{
        [communicator destroy];
        communicator = nil;
    }
}

+ (void)serviceAsync:(dispatch_block)block{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
        block();
    });
}

/**
 *  获取服务代理实例
 *
 *  @param serviceName
 *  @param serviceCls
 *
 *  @return ICEObjectPrx
 */
+ (id<ICEObjectPrx>) getServicePrx:(NSString*)serviceName class:(Class)serviceCls{
    
    id<ICEObjectPrx> proxy = [cls2PrxMap objectForKey:serviceName];
    if(proxy != nil){
        lastAccessTimestamp = [[NSDate date] timeIntervalSince1970]*1000;
        return proxy;
    }
    proxy = [IceClientUtil createIceProxy:[IceClientUtil getICECommunicator] serviceName:serviceName class:serviceCls];
    [cls2PrxMap setObject:proxy forKey:serviceName];
    lastAccessTimestamp = [[NSDate date] timeIntervalSince1970]*1000;
    return proxy;
}

/**
 *  创建ICE连接器
 *
 *  @param c           ICECommunicator
 *  @param serviceName serviceName
 *  @param serviceCls  服务代理类
 *
 *  @return <#return value description#>
 */
+ (id<ICEObjectPrx>) createIceProxy:(id<ICECommunicator>)c serviceName:(NSString*)serviceName class:(Class)serviceCls {
    id<ICEObjectPrx> proxy = nil;
    @try{
        ICEObjectPrx* base = [communicator stringToProxy:serviceName];
        base = [base ice_invocationTimeout:idleTimeOutSeconds];
        //SEL selector = NSSelectorFromString(@"checkedCast:");
        //proxy = [serviceCls performSelector:@selector(checkedCast:) withObject:base];
        proxy = [serviceCls checkedCast:base];
        return proxy;
    } @catch(ICEEndpointParseException* ex) {
        return (ICEObjectPrx*)ex;
    } @catch(ICEException* ex) {
        return (ICEObjectPrx*)ex;
    }@catch(NSException* ex){
        return (ICEObjectPrx*)ex;
    }
}

+ (void)createMonitoerThread{
    stoped = NO;
    monitorThread = [[NSThread alloc]initWithTarget:self selector:@selector(monitor) object:nil];
    [monitorThread start];
}

+ (void) monitor{
    while(!stoped){
        @try{
            // 让当前线程睡眠 5.0 秒
            [NSThread sleepForTimeInterval:5.0f];
            UInt64 nowTime = [[NSDate date] timeIntervalSince1970]*1000;
            if(lastAccessTimestamp + idleTimeOutSeconds * 1000L < nowTime){
                [IceClientUtil closeCommunicator:true];
            }
        }@catch(NSException * e){
            NSLog(@"%@",[e description]);
        }
    }
}

@end