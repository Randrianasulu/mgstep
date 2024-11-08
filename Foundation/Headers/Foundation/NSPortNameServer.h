/*
   NSPortNameServer.h

   Interface to the port registration service used by the DO system.

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	October 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPortNameServer
#define _mGSTEP_H_NSPortNameServer

#include <Foundation/NSObject.h>
#include <Foundation/NSMapTable.h>

@class NSPort;
@class NSString;
@class NSMutableData;
@class NSFileHandle;

@interface NSPortNameServer : NSObject
{
	NSFileHandle *handle;				// File handle to talk to domap.
	NSMutableData *data;				// Where to accumulated incoming data.
	unsigned _expecting;				// Length of data we want.
	NSMapTable *portMap;				// Registered ports information.
	NSMapTable *nameMap;				// Registered names information.
}

//+ (NSPortNameServer *) systemDefaultPortNameServer;		// shared instance
+ (id) defaultPortNameServer;

- (NSPort*) portForName:(NSString*)name;
//- (NSPort*) portForName:(NSString*)name onHost:(NSString*)host;
- (NSPort*) portForName:(NSString*)name onHost:(NSString*)host;
//- (BOOL) registerPort:(NSPort*)port forName:(NSString*)name;
- (BOOL) registerPort:(NSPort*)port forName:(NSString*)name;
- (void) removePortForName:(NSString*)name;

- (void) _removePort:(NSPort*)port;		// remove all names for port (private)

@end

#endif /* _mGSTEP_H_NSPortNameServer */
