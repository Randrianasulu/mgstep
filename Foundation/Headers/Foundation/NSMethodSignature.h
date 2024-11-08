/*
   NSMethodSignature.h

   Obj-C Method Signature class

   Copyright (C) 1995, 1998 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995
   Rewrite:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSMethodSignature
#define _mGSTEP_H_NSMethodSignature

#include <Foundation/NSObject.h>

typedef struct	{					// Info about layout of arguments. Extended 
	int offset;						// from the original OpenStep version to 
	unsigned size;					// let us know if the arg is passed in 
	const char *type;				// registers or on the stack.  OS 4.0 only
	unsigned align;
	unsigned qual;
	BOOL isReg;
} NSArgumentInfo;


@interface NSMethodSignature : NSObject
{
    const char *methodTypes;
    unsigned argFrameLength;
    unsigned numArgs;
    NSArgumentInfo *info;
}

+ (NSMethodSignature*) signatureWithObjCTypes:(const char*)types;

- (NSArgumentInfo) argumentInfoAtIndex:(unsigned)index;			// OS 4.0 only

- (BOOL) isOneway;
- (const char*) getArgumentTypeAtIndex:(unsigned)index;
- (const char*) methodReturnType;
- (unsigned) methodReturnLength;
- (unsigned) numberOfArguments;
- (unsigned) frameLength;

@end


@interface NSMethodSignature (mGSTEP)

- (NSArgumentInfo*) methodInfo;
- (const char*) methodType;

@end

#endif /* _mGSTEP_H_NSMethodSignature */
