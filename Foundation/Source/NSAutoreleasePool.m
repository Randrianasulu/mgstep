/*
   NSAutoreleasePool.m

   Auto release pool for delayed disposal of objects.

   Copyright (C) 1995-2017 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	January 1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSThread.h>


#define INITIAL_POOL_SIZE 32	// size of the first _released array.

								// When `NO', autoreleased objects are not 
								// actually recorded in an NSAutoreleasePool, 
								// and are not sent a `release' message.
static BOOL __autoreleaseEnabled = YES;
static IMP __allocImp;
static IMP __initImp;
								// When the _released_count of a pool gets over 
								// this value, we raise an exception.  This can 
								// be adjusted with -setPoolCountThreshhold 
static unsigned __poolCountThreshold = UINT_MAX;

				// access to thread variables belonging to NSAutoreleasePool.
#define THREAD_VARS (&(((NSThread*)objc_thread_get_data())->_autorelease_vars))

								// Functions for managing a per-thread cache of 
								// NSAutoreleasedPool's already alloc'ed.  The 
								// cache is kept in the autorelease_thread_var 
static inline void				// structure, which is an ivar of NSThread.
init_pool_cache (struct autorelease_thread_vars *tv)
{
	tv->pool_cache_size = 32;
	tv->pool_cache_count = 0;
	tv->thread_in_dealloc = NO;
	tv->pool_cache = malloc (tv->pool_cache_size * sizeof(id));
}

static void
push_pool_to_cache (struct autorelease_thread_vars *tv, id p)
{
	if (!tv->pool_cache)
		init_pool_cache (tv);
	else if (tv->pool_cache_count == tv->pool_cache_size)
		{
		tv->pool_cache_size *= 2;
		tv->pool_cache = realloc (tv->pool_cache, tv->pool_cache_size * sizeof(id));
		}

	tv->pool_cache[tv->pool_cache_count++] = p;
}

static id
pop_pool_from_cache (struct autorelease_thread_vars *tv)
{
	return tv->pool_cache[--(tv->pool_cache_count)];
}


@implementation NSAutoreleasePool

+ (void) initialize
{
	if (self == [NSAutoreleasePool class])
		{
		objc_thread_set_data([NSThread new]);	// configure the main thread
		__allocImp = [self methodForSelector: @selector(alloc)];
		__initImp = [self instanceMethodForSelector: @selector(init)];
		}
}

+ (id) alloc
{				
	struct autorelease_thread_vars *tv = THREAD_VARS;
												// if an existing autorelease  
	if (tv->pool_cache_count)					// pool is available return it
		return pop_pool_from_cache (tv);		// instead of alloc'ing a new

	return NSAllocateObject(self);
}

+ (id) new
{
	id arp = (*__allocImp)(self, @selector(alloc));

	return (*__initImp)(arp, @selector(init));
}

+ (void) enableRelease:(BOOL)enable			{ __autoreleaseEnabled = enable; }
+ (void) setPoolCountThreshhold:(unsigned)c	{ __poolCountThreshold = c; }
+ (void) enableDoubleReleaseCheck:(BOOL)en	{}

- (id) init
{
	struct autorelease_thread_vars *tv;
										// Allocate the array that will be the
	if (!_released_head)				// new head of the list of arrays.
		{
		unsigned s = sizeof(struct autorelease_array_list);

		_released = malloc (s + (INITIAL_POOL_SIZE * sizeof(id)));
		_released->next = NULL;			// Initially there is no NEXT array in
		_released->count = 0;			// the list, so NEXT == NULL.
		_released->size = INITIAL_POOL_SIZE;
		_released_head = _released;
		}
	else								// Already initialized; (it came from
		{								// autorelease_pool_cache); we don't 
		_released = _released_head;		// have to allocate new array list 
		_released->count = 0;			// memory.
		}

	_released_count = 0;				// Pool is initially empty

	tv = THREAD_VARS;
	_child = nil;
	if((_parent = tv->current_pool))	// Install self as current pool
		tv->current_pool->_child = self;
	tv->current_pool = self;

	return self;
}

+ (void) addObject:(id)anObj
{
	NSAutoreleasePool *pool = THREAD_VARS->current_pool;

	if (pool)
		[pool addObject: anObj];
	else
		{
		NSAutoreleasePool *arp = [NSAutoreleasePool new];

		if (anObj)
			NSLog(@"autorelease called without pool for object (%lx) of class %s\n",
				(unsigned long)anObj, [NSStringFromClass([anObj class]) cString]);
		else
			NSLog(@"autorelease called without pool for nil object.\n");
		[arp release];
		}
}

- (void) addObject:(id)anObj
{
	if (!__autoreleaseEnabled)		// do nothing if global, static variable 
		return;						// AUTORELEASE_ENABLED is not set

	if (_released_count >= __poolCountThreshold)
		[NSException raise: NSGenericException
					 format: @"AutoreleasePool count threshhold exceeded."];
												// Get new array for the list,  
	if (_released->count == _released->size)	// if the current one is full.
		{
		if (_released->next)				// There is an already-allocated
			{			 					// one in the chain; use it. 
			_released = _released->next;
			_released->count = 0;
			}
		else								// We are at the end of the chain, 
			{								// and need to allocate a new one.
	  		struct autorelease_array_list *new_released;
	 		unsigned new_size = _released->size * 2;
	 		unsigned s = sizeof(struct autorelease_array_list);

	  		new_released = malloc(s + (new_size * sizeof(id)));
			new_released->next = NULL;
			new_released->size = new_size;
			new_released->count = 0;
			_released->next = new_released;
			_released = new_released;
		}	}
											// Put object at end of the list
	_released->objects[_released->count] = anObj;
	(_released->count)++;					// Keep track of the total number  
											// of objects autoreleased across
	THREAD_VARS->total_objects_count++;		// all pools.
										 
	_released_count++;						// Track total number of objects
}											// autoreleased in this pool

- (void) _dealloc							// actually dealloc this auto pool
{
	struct autorelease_array_list *a;

	for (a = _released_head; a;)
		{
		void *n = a->next;

		free(a);
		a = n;
		}

	[super dealloc];
}

- (void) dealloc
{
	struct autorelease_array_list *released;
	struct autorelease_thread_vars *tv;
	NSAutoreleasePool **cp; // If there are NSAutoreleasePools below us in the
	int i;					// stack of NSAutoreleasePools, then deallocate
							// them also.  The (only) way we could get in this 
							// situation (in correctly written programs, that
	if (_child)				// don't release NSAutoreleasePools in weird ways),
		[_child dealloc];	// is if an exception threw us up the stack.

									// Simplify debug by checking to see if the
									// user already dealloced the object before 
									// trying to release it.  Also, take object  
									// out of the released list just before 
    released = _released_head;		// releasing it, so that if we are doing
									// "double_release_check"ing, then
	while (released)				// autoreleaseCountForObject: won't find
		{							// the objectwe are currently releasing.
		for (i = 0; i < released->count; i++)
			{
			id anObject = released->objects[i];
	
			released->objects[i] = nil;

			[anObject release];
			}
		released = released->next;
		}

	tv = THREAD_VARS;							// Uninstall ourselves as the
    cp = &(tv->current_pool);					// current pool; install our 
    *cp = _parent;								// parent pool
    if (*cp)
		(*cp)->_child = nil;

	if(tv->thread_in_dealloc)					// cleanup if thread in dealloc
		{
		[self _dealloc];						// actually dealloc self

		if(!(_parent))							// if no parent we are top pool
			{
			while (tv->pool_cache_count)		// release inactive pools in
				{								// the pools stack cache
				id pool = pop_pool_from_cache(tv);

				[pool _dealloc];
				}

			if (tv->pool_cache)
				free(tv->pool_cache);
		}	}
	else										// Don't deallocate self, just
    	push_pool_to_cache (tv, self);			// push to cache for later use
		
	NO_WARN;
}

- (oneway void) release						{ [self dealloc]; }

- (id) retain
{
	[NSException raise: NSGenericException
				 format: @"Don't call `-retain' on a NSAutoreleasePool"];

	return self;
}

- (id) autorelease
{
	[NSException raise: NSGenericException
				 format: @"Don't call `-autorelease' on a NSAutoreleasePool"];

	return self;
}

#if 0								// FIX ME incomplete, see libojbc2 README
#ifdef __LIBOBJC_RUNTIME_H_INCLUDED__

- (void) _ARCCompatibleAutoreleasePool		{ /* indicates ARC support */ }

+ (void) addObject:(id)object				{ objc_autorelease(object); }
- (void) addObject:(id)object				{ objc_autorelease(object); }

- (id) init
{
	if (self = [super init])
        _autoreleasePool = objc_autoreleasePoolPush();

    return self;
}

- (void) dealloc
{
	objc_autoreleasePoolPop(_autoreleasePool);

	NO_WARN;
}

#endif  /* __LIBOBJC_RUNTIME_H_INCLUDED__ */
#endif

@end
