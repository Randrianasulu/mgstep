/*
   NSAutoreleasePool.h

   Interface to NSAutoreleasePool

   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSAutoreleasePool
#define _mGSTEP_H_NSAutoreleasePool

#include <Foundation/NSObject.h>

										// Each pool holds it's objects to be 
struct autorelease_array_list			// released in a linked-list of these 
{										// structures.
	struct autorelease_array_list *next;
	unsigned size;
	unsigned count;
	id objects[0];
};


@interface NSAutoreleasePool : NSObject
{								// When dealloc'ed parent becomes current pool
	NSAutoreleasePool *_parent;
								// This pointer to our child pool is  necessary 
								// for co-existing with exceptions
	NSAutoreleasePool *_child;
								// A collection of the objects to be released
	struct autorelease_array_list *_released;
	struct autorelease_array_list *_released_head;

	unsigned _released_count;	// number of objects autoreleased in this pool
}

+ (void) enableRelease:(BOOL)enable;
+ (void) setPoolCountThreshhold:(unsigned)count;

+ (void) addObject:(id)anObject;
- (void) addObject:(id)anObject;

@end
							// Each thread has its own copy of these variables
							// A ptr to this structure is an ivar of NSThread
struct autorelease_thread_vars
{					// The current, default NSAutoreleasePool for the calling
					// thread; the one that will hold objects that are
					// arguments to [NSAutoreleasePool +addObject:]
	NSAutoreleasePool *current_pool;

					// Total number of objects autoreleased since the
					// thread was started, or since
					// -resetTotalAutoreleasedObjects was called in this thread
	unsigned total_objects_count;

	id *pool_cache;			// A cache of NSAutoreleasePool's already alloc'ed
	int pool_cache_size;	// Caching old pools instead of dealloc / realloc
	int pool_cache_count;	// saves time

	BOOL thread_in_dealloc;
};

#endif /* _mGSTEP_H_NSAutoreleasePool */
