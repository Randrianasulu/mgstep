/*
   NSDistantObject.h

   NSProxy subclass that stands-in for other objects or those to be created

   Copyright (C) 2015 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	Oct 2015

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSDistantObject
#define _mGSTEP_H_NSDistantObject

#include <Foundation/NSProxy.h>

@class NSConnection;


@interface NSDistantObject : NSProxy  <NSCoding>
{
	NSConnection *_connection;
	id _local;
//	NSUInteger _target;
//	id _object;
	NSUInteger _handle;
	Protocol *_protocol;
}

+ (NSDistantObject*) proxyWithLocal:(id)local connection:(NSConnection*)c;
+ (NSDistantObject*) proxyWithTarget:(NSUInteger)target connection:(NSConnection*)c;

- (id) initWithLocal:(id)local connection:(NSConnection*)c;
- (id) initWithTarget:(NSUInteger)target connection:(NSConnection*)c;

- (NSConnection*) connectionForProxy;
- (void) setProtocolForProxy:(Protocol*)aProtocol;

@end


@interface NSDistantObject (mGSTEPExtensions) //<GCFinalization>

+ (void) _setDebug:(int)val;

- (id) awakeAfterUsingCoder:(NSCoder*)aDecoder;
- (void) gcFinalize;

@end

#endif /* _mGSTEP_H_NSDistantObject */
