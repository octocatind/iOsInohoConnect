//
//  inohoConnectionManager.m
//  MyApp
//
//  Created by Ashish Singh on 20/06/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "InohoConnectionManager.h"

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
    bool _foundHome;
    int _numSearches;
    NSString *_homeIP;
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
        NSString* homeip = @"http://192.168.1.121";
        
        if([self isItHome: homeip]){//wise guess
            return homeip;
        } else {//wise guess failed lets try brute force
            [self findHomeFromAllAddresses];
            if(_foundHome) {
                return _homeIP;
            } else {//not found let's load cloud
                return @"http://cloud.inoho.com/home";
            }
        }
    } else {
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
            NSLog(@"%@", strData);
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

- (BOOL)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress {
    BOOL result = FALSE;
    SCNetworkReachabilityRef reachability = NULL;
    
    reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)hostAddress);
    
    _reachabilityRef = reachability;
    
    if (reachability == NULL)
    {
        NSLog(@"Error Reachability is NULL - internet connection not available");
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


- (void)findHomeFromAllAddresses
{
    //dispatch_queue_t backgroundQueue;
    //backgroundQueue = dispatch_queue_create("com.inoho.bgqueue", DISPATCH_QUEUE_CONCURRENT);//DISPATCH_QUEUE_CONCURRENT);
    //backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    
    NSOperationQueue * findHomeQueue = [[NSOperationQueue alloc]init];
    findHomeQueue.name = @"com.inoho.findHomeQueue";
    findHomeQueue.maxConcurrentOperationCount = 10;
    
    _foundHome = false;
    _numSearches = 0;
    for (int ii=2; ii<256; ii++) {
        NSString * ipFirstPart = @"http://192.168.1.";
        NSString * ipSecondPart = [@(ii) stringValue];
        
        NSString * wholeIp = [NSString stringWithFormat:@"%@%@", ipFirstPart, ipSecondPart];
        NSLog(@"Going to Ping %@", wholeIp);
        
//        dispatch_async(backgroundQueue, ^(void) {
//            [self isItHomeExt:wholeIp];
//        });
        
        [findHomeQueue addOperationWithBlock:^{
            [self isItHomeExt:wholeIp];
        }];
        
    }
    
    
    do {
        //[NSThread sleepForTimeInterval:0.1];
        if(_foundHome) {
            [findHomeQueue cancelAllOperations];
            break;
        }
    } while (_numSearches <254);
    
    NSLog(@"Home is at : %@", _homeIP);
    //dispatch_release(backgroundQueue);
}

-(BOOL) isItHomeExt: (NSString *) homeAddress {
    BOOL result = FALSE;
    //[[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
    NSString* homeQueryAddress = [homeAddress stringByAppendingString: @"/inohocontroller"];
    // Send a synchronous request
    NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:homeQueryAddress]
                                                 cachePolicy:NSURLRequestUseProtocolCachePolicy
                                             timeoutInterval:2.0];
    
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
            NSLog(@"%@", strData);
        }
        else {
            NSLog(@"Array: %@ for %@", jsonObject, homeAddress);
            if([jsonObject objectForKey:@"success"]){
                result = TRUE;
                _foundHome = true;
                _homeIP = homeAddress;
            }
        }
    } else {
        NSLog(@"Its not home %@", homeAddress);
        
    }
    _numSearches++;
    return result;
}

@end
