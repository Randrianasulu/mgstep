/*
   Protocol.h

   Declare the class Protocol for Objective C programs

   Copyright (C) 1997 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Protocol
#define _mGSTEP_H_Protocol

#include <Foundation/NSObject.h>
#include <Foundation/Private/protocol.h>


@interface Protocol : NSObject
{
@private
	char *_protocolName;
	struct objc_protocol_list *protocol_list;
	struct objc_method_description_list *instance_methods; 
	struct objc_method_description_list *class_methods; 
}

- (const char *) name;

- (BOOL) conformsTo:(Protocol *)aProtocolObject;		// test conformance

- (struct objc_method_description *) descriptionForInstanceMethod:(SEL)aSel;
- (struct objc_method_description *) descriptionForClassMethod:(SEL)aSel;

@end

#endif /* _mGSTEP_H_Protocol */
