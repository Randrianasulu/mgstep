/*
   NSPortMessage.h

   Distributed Objects packets are made of these.

   Copyright (C) 2010 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	January 2010

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPortMessage
#define _mGSTEP_H_NSPortMessage

#include <Foundation/NSObject.h>
#include <Foundation/NSDate.h>

@class NSArray;
@class NSPort;
@class NSDate;


@interface NSPortMessage : NSObject
{
	NSArray * _components;
}

- (id) initWithSendPort:(NSPort *)sendPort
			receivePort:(NSPort *)receivePort
			components:(NSArray *)components;

- (NSArray *) components;

- (NSPort *) receivePort;
- (NSPort *) sendPort;

//- (uint32_t) msgid;
//- (void) setMsgid:(uint32_t)msgid;

@end


@interface NSPortMessage (mGSTEP)

+ (id) _portMessageWithSendPort:(NSPort *)sendPort
					receivePort:(NSPort *)receivePort
					capacity:(unsigned)capacity;
@end


@interface NSPortMessage (TcpInPacket)

- (id) replyOutPort;
- (id) receivingInPort;

- (int) _fillFromSocket:(int)s;
+ (void) _getPacketSize:(int*)size
			andSendPort:(id*)sp
			andReceivePort:(id*)rp
			fromSocket:(int)s;
@end


@interface NSPortMessage (TcpOutPacket)

- (id) replyInPort;
+ (unsigned) prefixSize;

- (void) _writeToSocket:(int)s 
		   withSendPort:(id)sp
		   withReceivePort:(id)rp
		   timeout:(NSTimeInterval)t;
@end

#endif  /* _mGSTEP_H_NSPortMessage */
