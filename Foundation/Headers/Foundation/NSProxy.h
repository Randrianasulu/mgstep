/*
   NSProxy.h

   Abstract class of objects that act as stand-ins for other objects

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSProxy
#define _mGSTEP_H_NSProxy

#include <Foundation/NSObject.h>


@interface NSProxy  <NSObject>
{
@public
    Class isa;
@private
    unsigned int _retain_count;
}

+ (id) alloc;
+ (Class) class;
+ (void) load;
+ (BOOL) respondsToSelector:(SEL)aSelector;

- (void) dealloc;
- (NSString*) description;

- (void) forwardInvocation:(NSInvocation*)anInvocation;
- (NSMethodSignature*) methodSignatureForSelector:(SEL)aSelector;

//- (void) finalize;	// gc inovkes on receiver before dispoing of its mem

@end

#endif /* _mGSTEP_H_NSProxy */
