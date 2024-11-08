/*
   NSEnumerator.h

   Collection enumeration primitives

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Jan 2000

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSEnumerator
#define _mGSTEP_H_NSEnumerator

#include <Foundation/NSObject.h>

@class NSArray;


@interface NSEnumerator : NSObject

- (id) nextObject;
- (NSArray *) allObjects;

@end


/*
   NSFastEnumeration protocol is implemented by collection objects to allow
   a fast and safe enumeration of their contents.  The Obj-C language supports
   this with a "for...each" construct that can be used with such objects.
   
   Implement to either fill the passed in buffer array or export a reference
   via state->itemsPtr.  See Apple's FastEnumerationSample for more info.
*/

typedef struct {
	unsigned long state;				// state to be used by iterator
	id *itemsPtr;						// returned C array reference
	unsigned long *mutationsPtr;		// state to detect mutations
	unsigned long extra[5];
} NSFastEnumerationState;


@protocol NSFastEnumeration

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState *)state
								   objects:(id [])buffer
								     count:(NSUInteger)len;
@end

#endif /* _mGSTEP_H_NSEnumerator */
