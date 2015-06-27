//
//  InohoConnectionManager.h
//  MyApp
//
//  Created by Ashish Singh on 20/06/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//

#ifndef MyApp_InohoConnectionManager_h
#define MyApp_InohoConnectionManager_h

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#include <arpa/inet.h>

typedef enum : NSInteger {
    UNKNOWN = 0,
    NotReachable,
    ReachableViaWiFi,
    ReachableViaWWAN
} NetworkStatus;

extern NSString *kInohoConnectionChangeNotification;

@interface InohoConnectionManager : NSObject{
    
}

-(BOOL) initializeConnectionManager;
-(BOOL) currentConnectionState;
-(NSString*) getUrlToLoad;
//- (BOOL)startNotifier;

@end





#endif
