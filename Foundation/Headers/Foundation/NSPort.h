/*
   NSPort.h

   Objects representing one end of a communication channel in which
   the other end typically resides in a different thread or task.

   Copyright (C) 1994-2016 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	July 1994
   Rewrite: Richard Frith-Macdonald <richard@brainstorm.co.u>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPort
#define _mGSTEP_H_NSPort

#include <Foundation/NSObject.h>
#include <Foundation/NSDate.h>

@class NSData;
@class NSConnection;
@class NSRunLoop;
@class NSString;
@class NSPortMessage;

typedef int NSSocketNativeHandle;
														// Notification Strings
extern NSString *NSPortTimeoutException;				// OPENSTEP
extern NSString *NSPortDidBecomeInvalidNotification;

extern NSString *InPortClientBecameInvalidNotification;
extern NSString *InPortAcceptedClientNotification;


@interface NSPort : NSObject  <NSCoding, NSCopying>
{
	BOOL _is_valid;
	id _delegate;

@public
	void *_cfSocket;
}

+ (NSPort*) port;

- (BOOL) isValid;
- (void) invalidate;
- (void) setDelegate:(id)anObject;
- (id) delegate;

- (void) addConnection:(NSConnection*)connection		// add receiver to rl
			 toRunLoop:(NSRunLoop*)runLoop
			 forMode:(NSString*)mode;
- (void) removeConnection:(NSConnection*)connection
			  fromRunLoop:(NSRunLoop*)runLoop
			  forMode:(NSString*)mode;

- (void) scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void) removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

@end


@interface NSObject (NSPortDelegateMethods)				// delegate implements

- (void) handlePortMessage:(NSPortMessage *)message;

@end


@interface NSPort (mGSTEP_DO)

+ (Class) _outPortClass;
+ (Class) _inPortClass;

+ (id) _newOutPortWithPortNumber:(unsigned)portNum
					  andAddress:(struct in_addr)address;
+ (id) _newForReceivingFromPortNumber:(unsigned short)n;
+ (id) _newForSendingToSockaddr:(struct sockaddr_in*)sockaddr 
			 withAcceptedSocket:(int)sock
			 pollingInPort:ip;

- (int) portNumber;
- (void) close;

+ (id) newForReceiving;											// InPort
+ (id) newForReceivingFromRegisteredName:(NSString*)name;
+ (id) newForReceivingFromRegisteredName:(NSString*)name fromPort:(int)port;

		// When a RunLoop is handling this InPort, and a new incoming packet 
		// arrives, INVOCATION will be invoked with the new packet as an 
		// argument.  The INVOCATION is responsible for releasing the packet.
- (void) setReceivedPacketInvocation:(id)invocation;

		// An alternative to the above way for receiving packets from this 
		// port.  Get a packet from the net and return it.  If no packet is 
		// received  within MILLISECONDS, then return nil.  The caller is 
		// responsible for releasing the packet.
- (id) receivePacketWithTimeout:(int)milliseconds;

+ (id) newForSendingToRegisteredName:(NSString*)name			// OutPort
							  onHost:(NSString*)hostname;
- (BOOL) sendPacket:packet timeout:(NSTimeInterval)t;

@end


@interface NSSocketPort : NSPort
{
    void *_receiver;			// CF socket
    void *_connectors;
    void *_runloops;
    void *_data;
    id _lock;
//    id _signature;
//    unsigned int _maxSize;
//    unsigned int _maxSockets;
}

- (id) init;
- (id) initWithTCPPort:(unsigned short)port;

- (id) initWithProtocolFamily:(int)family
				   socketType:(int)type
				     protocol:(int)protocol
					   socket:(NSSocketNativeHandle)socket;
- (id) initWithProtocolFamily:(int)family
				   socketType:(int)type
				     protocol:(int)protocol
				     address:(NSData *)address;

- (id) initRemoteWithTCPPort:(unsigned short)port host:(NSString *)hostName;
- (id) initRemoteWithProtocolFamily:(int)family
						 socketType:(int)type
						   protocol:(int)protocol
						    address:(NSData *)address;
- (int) protocolFamily;
- (int) socketType;
- (int) protocol;

- (NSData *) address;
- (NSSocketNativeHandle) socket;

@end


@interface NSMessagePort : NSPort			// local comm only
{
	void *_port;
}
@end

#endif /* _mGSTEP_H_NSPort */
