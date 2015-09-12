//
//  InohoPing.m
//  MyApp
//
//  Created by Ashish Singh on 25/06/15.
//  Copyright (c) 2015 Ashish Singh. All rights reserved.
//

#import "InohoPing.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>


static uint16_t in_cksum(const void *buffer, size_t bufferLen)
// This is the standard BSD checksum code, modified to use modern types.
{
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);	/* add hi 16 to low 16 */
    sum += (sum >> 16);			/* add carry */
    answer = (uint16_t) ~sum;   /* truncate to 16 bits */
    
    return answer;
}

@implementation InohoPing {
    CFSocketRef             _socket;
}

@synthesize identifier         = _identifier;
@synthesize nextSequenceNumber = _nextSequenceNumber;


- (BOOL)isIpAccesible:(NSString* )ipAddress {
    //self->_host = CFHostCreateWithName(NULL, (__bridge CFStringRef) self.hostName);
    self.hostAddress = [ipAddress dataUsingEncoding:NSUTF8StringEncoding];
    [self initPingEnv];
    [self constantPinger];
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (1);
    
    return TRUE;
}

//- (void)hostResolutionDone: (NSString *) hostName
//// Called by our CFHost resolution callback (HostResolveCallback) when host
//// resolution is complete.  We just latch the first IPv4 address and kick
//// off the pinging process.
//{
//    Boolean     resolved;
//    NSArray *   addresses;
//    
//    // Find the first IPv4 address.
//    CFHostRef host = CFHostCreateWithName(NULL, (__bridge CFStringRef) hostName);
//    
//    addresses = (__bridge NSArray *) CFHostGetAddressing(host, &resolved);
//    if ( resolved && (addresses != nil) ) {
//        resolved = false;
//        for (NSData * address in addresses) {
//            const struct sockaddr * addrPtr;
//            
//            addrPtr = (const struct sockaddr *) [address bytes];
//            if ( [address length] >= sizeof(struct sockaddr) && addrPtr->sa_family == AF_INET) {
//                self.hostAddress = address;
//                resolved = true;
//                break;
//            }
//        }
//    }
//    
//    
//    // If all is OK, start pinging, otherwise shut down the pinger completely.
//    
//    if (resolved) {
//        NSLog(@"Resolved");
//        [self initPingEnv];
//        //[self startWithHostAddress];
//    } else {
//        NSLog(@"Failed to resolve");
//        //[self didFailWithError:[NSError errorWithDomain:(NSString *)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil]];
//    }
//}

- (void)sendPing {
    //assert(self.pinger != nil);
    [self sendPingWithData:nil];
}

-(void) constantPinger {
    assert(self.sendTimer == nil);
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(sendPing) userInfo:nil repeats:YES];
}

- (void)initPingEnv
// We have a host address, so let's actually start pinging it.
{
    int                     err;
    int                     fd;
    const struct sockaddr * addrPtr;
    
    assert(self.hostAddress != nil);
    
    // Open the socket.
    
    addrPtr = (const struct sockaddr *) [self.hostAddress bytes];
    
    fd = -1;
    err = 0;
//    switch (addrPtr->sa_family) {
//        case AF_INET: {
//            fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
//            if (fd < 0) {
//                err = errno;
//            }
//        } break;
//        case AF_INET6:
//            assert(NO);
//            // fall through
//        default: {
//            err = EPROTONOSUPPORT;
//        } break;
//    }
    
    fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (fd < 0) {
        err = errno;
    }
    
    if (err != 0) {
        //failed
        NSLog(@"Failed");
    } else {
        CFSocketContext     context = {0, (__bridge void *)(self), NULL, NULL, NULL};
        CFRunLoopSourceRef  rls;
        
        // Wrap it in a CFSocket and schedule it on the runloop.
        
        self->_socket = CFSocketCreateWithNative(NULL, fd, kCFSocketReadCallBack, SocketReadCallback, &context);
        assert(self->_socket != NULL);
        
        // The socket will now take care of cleaning up our file descriptor.
        
        assert( CFSocketGetSocketFlags(self->_socket) & kCFSocketCloseOnInvalidate );
        fd = -1;
        
        rls = CFSocketCreateRunLoopSource(NULL, self->_socket, 0);
        assert(rls != NULL);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
        
        CFRelease(rls);
        //ready to roll
    }
    assert(fd == -1);
}

- (void)sendPingWithData:(NSData *)data
// See comment in header.
{
    int             err;
    NSData *        payload;
    NSMutableData * packet;
    ICMPHeader *    icmpPtr;
    ssize_t         bytesSent;
    
    // Construct the ping packet.
    
    payload = data;
    if (payload == nil) {
        payload = [[NSString stringWithFormat:@"%28zd bottles of beer on the wall", (ssize_t) 99 - (size_t) (self.nextSequenceNumber % 100) ] dataUsingEncoding:NSASCIIStringEncoding];
        assert(payload != nil);
        
        assert([payload length] == 56);
    }
    
    packet = [NSMutableData dataWithLength:sizeof(*icmpPtr) + [payload length]];
    assert(packet != nil);
    
    icmpPtr = [packet mutableBytes];
    icmpPtr->type = kICMPTypeEchoRequest;
    icmpPtr->code = 0;
    icmpPtr->checksum = 0;
    icmpPtr->identifier     = OSSwapHostToBigInt16(self.identifier);
    icmpPtr->sequenceNumber = OSSwapHostToBigInt16(self.nextSequenceNumber);
    memcpy(&icmpPtr[1], [payload bytes], [payload length]);
    
    // The IP checksum returns a 16-bit number that's already in correct byte order
    // (due to wacky 1's complement maths), so we just put it into the packet as a
    // 16-bit unit.
    
    icmpPtr->checksum = in_cksum([packet bytes], [packet length]);
    
    // Send the packet.
    
    if (self->_socket == NULL) {
        bytesSent = -1;
        err = EBADF;
    } else {
        bytesSent = sendto(
                           CFSocketGetNative(self->_socket),
                           [packet bytes],
                           [packet length],
                           0,
                           (struct sockaddr *) [self.hostAddress bytes],
                           (socklen_t) [self.hostAddress length]
                           );
        err = 0;
        if (bytesSent < 0) {
            err = errno;
        }
    }
    
    // Handle the results of the send.
    
    if ( (bytesSent > 0) && (((NSUInteger) bytesSent) == [packet length]) ) {
        
        // Complete success.  Tell the client.
        
//        if ( (self.delegate != nil) && [self.delegate respondsToSelector:@selector(simplePing:didSendPacket:)] ) {
//            [self.delegate simplePing:self didSendPacket:packet];
//        }
    } else {
        NSError *   error;
        
        // Some sort of failure.  Tell the client.
        
        if (err == 0) {
            err = ENOBUFS;          // This is not a hugely descriptor error, alas.
        }
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
//        if ( (self.delegate != nil) && [self.delegate respondsToSelector:@selector(simplePing:didFailToSendPacket:error:)] ) {
//            [self.delegate simplePing:self didFailToSendPacket:packet error:error];
//        }
    }
    
    self.nextSequenceNumber += 1;
}

- (BOOL)isValidPingResponsePacket:(NSMutableData *)packet
// Returns true if the packet looks like a valid ping response packet destined
// for us.
{
    BOOL                result;
    NSUInteger          icmpHeaderOffset;
    ICMPHeader *        icmpPtr;
    uint16_t            receivedChecksum;
    uint16_t            calculatedChecksum;
    
    result = NO;
    
    icmpHeaderOffset = [[self class] icmpHeaderOffsetInPacket:packet];
    if (icmpHeaderOffset != NSNotFound) {
        icmpPtr = (struct ICMPHeader *) (((uint8_t *)[packet mutableBytes]) + icmpHeaderOffset);
        
        receivedChecksum   = icmpPtr->checksum;
        icmpPtr->checksum  = 0;
        calculatedChecksum = in_cksum(icmpPtr, [packet length] - icmpHeaderOffset);
        icmpPtr->checksum  = receivedChecksum;
        
        if (receivedChecksum == calculatedChecksum) {
            if ( (icmpPtr->type == kICMPTypeEchoReply) && (icmpPtr->code == 0) ) {
                if ( OSSwapBigToHostInt16(icmpPtr->identifier) == self.identifier ) {
                    if ( OSSwapBigToHostInt16(icmpPtr->sequenceNumber) < self.nextSequenceNumber ) {
                        result = YES;
                    }
                }
            }
        }
    }
    
    return result;
}

+ (NSUInteger)icmpHeaderOffsetInPacket:(NSData *)packet
// Returns the offset of the ICMPHeader within an IP packet.
{
    NSUInteger              result;
    const struct IPHeader * ipPtr;
    size_t                  ipHeaderLength;
    
    result = NSNotFound;
    if ([packet length] >= (sizeof(IPHeader) + sizeof(ICMPHeader))) {
        ipPtr = (const IPHeader *) [packet bytes];
        assert((ipPtr->versionAndHeaderLength & 0xF0) == 0x40);     // IPv4
        assert(ipPtr->protocol == 1);                               // ICMP
        ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
        if ([packet length] >= (ipHeaderLength + sizeof(ICMPHeader))) {
            result = ipHeaderLength;
        }
    }
    return result;
}


//InohoPing read logic
- (void)readData
// Called by the socket handling code (SocketReadCallback) to process an ICMP
// messages waiting on the socket.
{
    int                     err;
    struct sockaddr_storage addr;
    socklen_t               addrLen;
    ssize_t                 bytesRead;
    void *                  buffer;
    enum { kBufferSize = 65535 };
    
    // 65535 is the maximum IP packet size, which seems like a reasonable bound
    // here (plus it's what <x-man-page://8/ping> uses).
    
    buffer = malloc(kBufferSize);
    assert(buffer != NULL);
    
    // Actually read the data.
    
    addrLen = sizeof(addr);
    bytesRead = recvfrom(CFSocketGetNative(self->_socket), buffer, kBufferSize, 0, (struct sockaddr *) &addr, &addrLen);
    err = 0;
    if (bytesRead < 0) {
        err = errno;
    }
    
    // Process the data we read.
    
    if (bytesRead > 0) {
        NSMutableData *     packet;
        
        packet = [NSMutableData dataWithBytes:buffer length:(NSUInteger) bytesRead];
        assert(packet != nil);
        
        // We got some data, pass it up to our client.
        
        if ( [self isValidPingResponsePacket:packet] ) {
//            if ( (self.delegate != nil) && [self.delegate respondsToSelector:@selector(simplePing:didReceivePingResponsePacket:)] ) {
//                [self.delegate simplePing:self didReceivePingResponsePacket:packet];
//            }
        } else {
//            if ( (self.delegate != nil) && [self.delegate respondsToSelector:@selector(simplePing:didReceiveUnexpectedPacket:)] ) {
  //              [self.delegate simplePing:self didReceiveUnexpectedPacket:packet];
    //        }
        }
    } else {
        
        // We failed to read the data, so shut everything down.
        
        if (err == 0) {
            err = EPIPE;
        }
        //[self didFailWithError:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil]];
    }
    
    free(buffer);
    
    // Note that we don't loop back trying to read more data.  Rather, we just
    // let CFSocket call us again.
}

//socket callback
static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
// This C routine is called by CFSocket when there's data waiting on our
// ICMP socket.  It just redirects the call to Objective-C code.
{
    InohoPing *    obj;
    
    obj = (__bridge InohoPing *) info;
    assert([obj isKindOfClass:[InohoPing class]]);
    
#pragma unused(s)
    assert(s == obj->_socket);
#pragma unused(type)
    assert(type == kCFSocketReadCallBack);
#pragma unused(address)
    assert(address == nil);
#pragma unused(data)
    assert(data == nil);
    
    [obj readData];
}


@end
