//
//  InohoPingManager.h
//  MyApp
//
//  Created by Ashish Singh on 24/06/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//

#ifndef MyApp_inohoPingManager_h
#define MyApp_inohoPingManager_h

#include "SimplePing.h"
#include <sys/socket.h>
#include <netdb.h>


typedef enum : NSInteger {
    PING_UNKNOWN = 0,
    PING_IN_PROGRESS,
    PING_SUCCESS,
    PING_FAILED
} PingStatus;


@interface InohoPingManager : NSObject <SimplePingDelegate>

- (PingStatus)runWithHostName:(NSString *)hostName;
- (void) searchForTheHomeIP;

//- (BOOL)isIpAccesible:(NSString* )ipAddress;

@property (nonatomic, strong, readwrite) SimplePing *   pinger;
@property (nonatomic, strong, readwrite) NSTimer *      sendTimer;
@property (nonatomic, readwrite) PingStatus pingResult;


@end

#endif
