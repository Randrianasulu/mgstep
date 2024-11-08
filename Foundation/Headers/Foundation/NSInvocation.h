/*
   NSInvocation.h

   Object rendering of an Obj-C message (action).

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSInvocation
#define _mGSTEP_H_NSInvocation

#include <Foundation/NSMethodSignature.h>


@interface NSInvocation : NSObject
{
	NSMethodSignature *_sig;
	NSArgumentInfo *_info;
	void *_cframe;
	void *_retval;
	id _target;
	SEL _selector;
	int _numArgs;

	struct __InvocationFlags {
		unsigned int forwarding:1;
		unsigned int retainArgs:1;
		unsigned int returnIsValid:1;
		unsigned int reserved:5;
	} _vf;
}

+ (NSInvocation*) invocationWithMethodSignature:(NSMethodSignature*)signature;

- (void) getArgument:(void*)buffer atIndex:(int)index;
- (void) setArgument:(void*)buffer atIndex:(int)index;
- (void) getReturnValue:(void*)buffer;
- (void) setReturnValue:(void*)buffer;
- (void) setSelector:(SEL)selector;
- (void) setTarget:(id)target;
- (SEL) selector;
- (id) target;

- (BOOL) argumentsRetained;									// Manage arguments
- (void) retainArguments;

- (void) invoke;											// Dispatch
- (void) invokeWithTarget:(id)target;

- (NSMethodSignature*) methodSignature;						// Signature

@end

#endif /* _mGSTEP_H_NSInvocation */
