//
//  InohoPingManager.m
//  MyApp
//
//  Created by Ashish Singh on 24/06/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#import "InohoPingManager.h"

static NSString * DisplayAddressForAddress(NSData * address) {
    int         err;
    NSString *  result;
    char        hostStr[NI_MAXHOST];
    
    result = nil;
    
    if (address != nil) {
        err = getnameinfo([address bytes], (socklen_t) [address length], hostStr, sizeof(hostStr), NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            result = [NSString stringWithCString:hostStr encoding:NSASCIIStringEncoding];
            assert(result != nil);
        }
    }
    
    return result;
}


@implementation InohoPingManager

@synthesize pinger    = _pinger;
@synthesize sendTimer = _sendTimer;

-(void) searchForTheHomeIP
{
    NSString * result;
    //get the ip of device and then go for individual ips
    //for now assume 192.168.1.*
    for (int ii=2; ii<256; ii++) {
        NSString * ipFirstPart = @"192.168.1.";
        NSString * ipSecondPart = [@(ii) stringValue];
        
        NSString * wholeIp = [NSString stringWithFormat:@"%@%@", ipFirstPart, ipSecondPart];
        
        //if([self runWithHostName:wholeIp] == PING_SUCCESS) {
        //lets use by address
        
//        struct sockaddr ipAddress;
//        ipAddress.sa_len = sizeof(ipAddress);
//        ipAddress.sa_family = AF_INET;
//        
        struct sockaddr_in ipAddress;
        bzero(&ipAddress, sizeof(ipAddress));
        ipAddress.sin_len = sizeof(ipAddress);
        ipAddress.sin_family = AF_INET;
        
        
        const char* ipAsChar = [wholeIp UTF8String];
        inet_pton(AF_INET, ipAsChar, &ipAddress.sin_addr);
        
//        size_t len = strlen(ipAsChar) + 1;
//        char macAddress [len];
//        memcpy(macAddress, ipAsChar, len);
//        
//        inet_pton(AF_INET, macAddress, &ipAddress.sa_data);
//        
        NSData * discoveryHost = [NSData dataWithBytes:&ipAddress length:ipAddress.sin_len];
        
        if([self runWithHostAddress:discoveryHost] == PING_SUCCESS) {
            result = wholeIp;
            //if(home) logic
            //break;
        }
    }
    NSLog(@"ip to home is: %@", result);
}

- (void)dealloc
{
    [self->_pinger stop];
    [self->_sendTimer invalidate];
}

- (NSString *)shortErrorFromError:(NSError *)error {
    NSString *      result;
    NSNumber *      failureNum;
    int             failure;
    const char *    failureStr;
    
    assert(error != nil);
    
    result = nil;
    
    // Handle DNS errors as a special case.
    
    if ( [[error domain] isEqual:(NSString *)kCFErrorDomainCFNetwork] && ([error code] == kCFHostErrorUnknown) ) {
        failureNum = [[error userInfo] objectForKey:(id)kCFGetAddrInfoFailureKey];
        if ( [failureNum isKindOfClass:[NSNumber class]] ) {
            failure = [failureNum intValue];
            if (failure != 0) {
                failureStr = gai_strerror(failure);
                if (failureStr != NULL) {
                    result = [NSString stringWithUTF8String:failureStr];
                    assert(result != nil);
                }
            }
        }
    }
    
    // Otherwise try various properties of the error object.
    
    if (result == nil) {
        result = [error localizedFailureReason];
    }
    if (result == nil) {
        result = [error localizedDescription];
    }
    if (result == nil) {
        result = [error description];
    }
    assert(result != nil);
    return result;
}

- (PingStatus)runWithHostName:(NSString *)hostName {
    assert(self.pinger == nil);
    
    self.pingResult = PING_UNKNOWN;
    
    self.pinger = [SimplePing simplePingWithHostName:hostName];
    assert(self.pinger != nil);
    
    self.pinger.delegate = self;
    [self.pinger start];
    self.pingResult = PING_IN_PROGRESS;
    
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (self.pingResult == PING_IN_PROGRESS);
    
    return self.pingResult;
}

- (PingStatus)runWithHostAddress:(NSData *)hostAddress {
    assert(self.pinger == nil);
    
    self.pingResult = PING_UNKNOWN;
    
    self.pinger = [SimplePing simplePingWithHostAddress:hostAddress];
    assert(self.pinger != nil);
    
    self.pinger.delegate = self;
    [self.pinger start];
    self.pingResult = PING_IN_PROGRESS;
    
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (self.pingResult == PING_IN_PROGRESS);

    return self.pingResult;
}

- (void)sendPing {
    self.pingResult = PING_IN_PROGRESS;
    
    assert(self.pinger != nil);
    [self.pinger sendPingWithData:nil];
}

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
#pragma unused(pinger)
    assert(pinger == self.pinger);
    assert(address != nil);
    
    NSLog(@"pinging %@", DisplayAddressForAddress(address));
    
    // Send the first ping straight away.
    
    [self sendPing];
    
    assert(self.sendTimer == nil);
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(error)
    NSLog(@"failed: %@", [self shortErrorFromError:error]);
    
    [self.sendTimer invalidate];
    self.sendTimer = nil;
    
    self.pingResult = PING_FAILED;
    self.pinger = nil;
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet {
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    uint numPackets = (unsigned int) OSSwapBigToHostInt16(((const ICMPHeader *) [packet bytes])->sequenceNumber);
    NSLog(@"#%u sent", numPackets);
    if(numPackets > 4) { //bailout after 5 packets
        [self.sendTimer invalidate];
        self.sendTimer = nil;
        
        self.pingResult = PING_FAILED;
        self.pinger = nil;
    } else {
        self.pingResult = PING_IN_PROGRESS;
    }
}

- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
#pragma unused(error)
    NSLog(@"#%u send failed: %@", (unsigned int) OSSwapBigToHostInt16(((const ICMPHeader *) [packet bytes])->sequenceNumber), [self shortErrorFromError:error]);
    
    self.pingResult = PING_FAILED;
    [self.sendTimer invalidate];
    self.sendTimer = nil;
    self.pinger = nil;

}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet {
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    NSLog(@"#%u received", (unsigned int) OSSwapBigToHostInt16([SimplePing icmpInPacket:packet]->sequenceNumber) );
    self.pingResult = PING_SUCCESS;
    [self.sendTimer invalidate];
    self.sendTimer = nil;
    self.pinger = nil;

}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
    const ICMPHeader *  icmpPtr;
    
#pragma unused(pinger)
    assert(pinger == self.pinger);
#pragma unused(packet)
    
    icmpPtr = [SimplePing icmpInPacket:packet];
    if (icmpPtr != NULL) {
        NSLog(@"#%u unexpected ICMP type=%u, code=%u, identifier=%u", (unsigned int) OSSwapBigToHostInt16(icmpPtr->sequenceNumber), (unsigned int) icmpPtr->type, (unsigned int) icmpPtr->code, (unsigned int) OSSwapBigToHostInt16(icmpPtr->identifier) );
    } else {
        NSLog(@"unexpected packet size=%zu", (size_t) [packet length]);
    }
    self.pingResult = PING_FAILED;
    [self.sendTimer invalidate];
    self.sendTimer = nil;
    
    self.pingResult = PING_FAILED;
    self.pinger = nil;
}

@end
