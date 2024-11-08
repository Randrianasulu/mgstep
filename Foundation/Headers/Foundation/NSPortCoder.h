/*
   NSPortCoder.h

   DO coder that transmits objects and proxy objects between NSConnections

   Copyright (C) 2005 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	April 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSPortCoder
#define _mGSTEP_H_NSPortCoder

#include <Foundation/NSObject.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSMapTable.h>

@class NSPort;
@class NSConnection;
@class NSArray;
@class CStream;


@interface NSPortCoder : NSCoder
{
@public
	int format_version;
	CStream *cstream;
	NSMapTable *classname_2_classname; 	// for changing class names on r/w
	int interconnect_stack_height;     	// number of nested root objects
	NSConnection *connection;
	unsigned sequence_number;
	int identifier;
}

#if 0  /* not yet implemented  */
+ (id) portCoderWithReceivePort:(NSPort*)recievePort		// dep in OSX 10.7
					   sendPort:(NSPort*)sendPort
					   components:(NSArray*)components;

- (id) initWithReceivePort:(NSPort*)recievePort
				  sendPort:(NSPort*)sendPort
				  components:(NSArray*)components;
- (void) dispatch;
#endif

- (NSConnection*) connection;

- (NSPort*) decodePortObject;
- (void) encodePortObject:(NSPort*)aPort;

- (BOOL) isBycopy;
- (BOOL) isByref;

+ (void) _setDebugging:(BOOL)flag;

@end


@interface NSObject (NSDistributedObjects)

- (Class) classForPortCoder;

- (id) replacementObjectForPortCoder:(NSPortCoder*)anEncoder;

@end

#endif /* _mGSTEP_H_NSPortCoder */
