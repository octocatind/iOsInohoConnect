//
//  inohoConnectionManager.m
//  MyApp
//
//  Created by Ashish Singh on 20/06/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "InohoConnectionManager.h"
//#import "InohoPingManager.h"
//#import "InohoPing.h"

NSString *kInohoConnectionChangeNotification = @"InohoConnectionChangeNotification";


static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
    NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
    NSCAssert([(__bridge NSObject*) info isKindOfClass: [InohoConnectionManager class]], @"info was wrong class in ReachabilityCallback");
    
    InohoConnectionManager* noteObject = (__bridge InohoConnectionManager *)info;
    // Post a notification to notify the client that the network reachability changed.
    [[NSNotificationCenter defaultCenter] postNotificationName: kInohoConnectionChangeNotification object: noteObject];
}


@implementation InohoConnectionManager {
    SCNetworkReachabilityRef _reachabilityRef;
}

-(BOOL) initializeConnectionManager {
    BOOL result = FALSE;
    result = [self reachabilityForInternetConnection];
    if(![self startNotifier]){
        NSLog(@"Error in starting notifier");
    }
    return result;
}

-(BOOL) currentConnectionState {
    return [self reachabilityForInternetConnection];
}

-(NetworkStatus) getCurrentNetworkState: (SCNetworkReachabilityRef) reachRef {
    SCNetworkReachabilityFlags flags;

    if (SCNetworkReachabilityGetFlags(reachRef, &flags))
    {
        if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
        {
            // The target host is not reachable.
            return NotReachable;
        }
        
        NetworkStatus returnValue = NotReachable;
        
        if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
        {
            /*
             If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
             */
            returnValue = ReachableViaWiFi;
        }
        
        if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
             (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
        {
            /*
             ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
             */
            
            if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
            {
                /*
                 ... and no [user] intervention is needed...
                 */
                returnValue = ReachableViaWiFi;
            }
        }
        
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
        {
            /*
             ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
             */
            returnValue = ReachableViaWWAN;
        }
        return returnValue;
    }
    return UNKNOWN;
}

-(NSString*) getUrlToLoad {
    if([self getCurrentNetworkState: _reachabilityRef] == ReachableViaWiFi) {
        NSString* homeip = @"http://192.168.1.123";
        
        if([self isItHome: homeip]){
            return homeip;
        } else {
            return @"http://cloud.inoho.com/home";
        }
        //return [self getURLByPingingPrefferdIPs];
    } else {
        //[self startNotifier];
        return @"http://cloud.inoho.com/home";
    }
    
}

-(BOOL) isItHome: (NSString *) homeAddress {
    BOOL result = FALSE;
    NSString* homeQueryAddress = [homeAddress stringByAppendingString: @"/inohocontroller"];
    // Send a synchronous request
    NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:homeQueryAddress]
                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                 timeoutInterval:5.0];
    
    NSURLResponse * response = nil;
    NSError * error = nil;
    NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest
                                      returningResponse:&response
                                                  error:&error];

    if (error == nil) {
        // Parse data here
        NSError *error = nil;
        NSString *strData = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        
        if (error != nil) {
            NSLog(@"Error parsing JSON.");
            NSLog(strData);
        }
        else {
            NSLog(@"Array: %@", jsonObject);
            if([jsonObject objectForKey:@"success"])
            result = TRUE;
        }
    } else {
        NSLog(@"Its not home");
        
    }
    return result;
}

//discovery of device IP will be done once we get a faster way to ping

///////////////////////////     \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
//
//
//-(NSString *) getURLByPingingPrefferdIPs {
//    NSString    *linkToHome = @"";
//    NSArray *ips = @[@"192.168.1.123"];
//    for (NSString *ip in ips) {
//        if([self pingAnIP:ip]) {
//            linkToHome = ip;
//            break;
//        }
//    }
//    return linkToHome;
//}

//-(BOOL) pingAnIP:(NSString *)hostName {
//    BOOL result = FALSE;
//    InohoPingManager *inPin = [[InohoPingManager alloc] init];
//    PingStatus pstat = [inPin runWithHostName:hostName];
//    return pstat == PING_SUCCESS ? TRUE : FALSE;
//}
//
//
/////////////////////////////////   \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

- (BOOL)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress {
    BOOL result = FALSE;
    SCNetworkReachabilityRef reachability = NULL;
    
    reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)hostAddress);
    
    _reachabilityRef = reachability;
    
    if (reachability == NULL)
    {
        NSLog(@"Error Reachability is NULL - internet connection not avilable");
    } else {
        NetworkStatus currentStatus = [self getCurrentNetworkState: _reachabilityRef];
        if(!(currentStatus == NotReachable  || currentStatus == UNKNOWN)){
            result = TRUE;
        }
    }
    
    return result;
}

- (BOOL)reachabilityForInternetConnection {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress:&zeroAddress];
}

- (BOOL)startNotifier {
    BOOL returnValue = NO;
    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context))
    {
        if (SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
        {
            returnValue = YES;
        }
    }
    
    return returnValue;
}


- (void)stopNotifier {
    if (_reachabilityRef != NULL)
    {
        SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    }
}


- (void)dealloc {
    [self stopNotifier];
    if (_reachabilityRef != NULL)
    {
        CFRelease(_reachabilityRef);
    }
}


@end
