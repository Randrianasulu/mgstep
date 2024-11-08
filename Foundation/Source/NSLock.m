/*
   NSLock.m

   Mutual exclusion locking classes 

   Copyright (C) 1996-2021 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:	1996
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	April 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSLock.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSException.h>


NSString *NSLockException = @"NSLockException";
NSString *NSConditionLockException = @"NSConditionLockException";
NSString *NSRecursiveLockException = @"NSRecursiveLockException";

static NSRecursiveLock *__globalLock = nil;		// global mutable data lock



#ifdef __USE_LIBOBJC2__

objc_thread_t  objc_thread_id(void)		{ return pthread_self(); }

int
objc_condition_broadcast (objc_condition_t c)	// Wake up all threads
{												// waiting on the condition
	return pthread_cond_broadcast(c);
}					// runtime version returns 0 on success and -1 on error

int
objc_condition_deallocate (objc_condition_t c)
{
	if (objc_condition_broadcast (c))			// legal to dealloc only if
		return -1;								// no other thread is using it

	return pthread_cond_destroy(c);
}

int
objc_condition_wait (objc_condition_t c, objc_mutex_t mutex)
{
	objc_thread_t tid;
	int e;

	if (! mutex || ! c)						// Validate arguments
		return -1;

	if (mutex->owner != (tid = objc_thread_id()))
		return -1;							// thread must own mutex

	if (mutex->depth == 1)					// must be locked only once
		return -1;

	mutex->depth = 0;						// virtual unlock of mutex
	mutex->owner = (objc_thread_t)NULL;

	// release mutex (atomic) and block waiting on condition variable
	e = pthread_cond_wait(c, &mutex->backend);

	mutex->owner = tid;						// thread owns mutex on any return
	mutex->depth = 1;

	return e;
}

int
objc_mutex_trylock (objc_mutex_t mutex)
{
	int e = -1;

	if (mutex && (e = pthread_mutex_trylock(&mutex->backend)) == 0)
		if (++mutex->depth == 1)
			mutex->owner = pthread_self();

	return (e != 0) ? -1 : mutex->depth;
}

int objc_mutex_lock (objc_mutex_t mutex)
{
	int e = -1;

	if (mutex && ((e = pthread_mutex_lock(&mutex->backend)) == 0))
		if (++mutex->depth == 1)
			mutex->owner = pthread_self();
	
	return (e != 0) ? -1 : mutex->depth;
}

int objc_mutex_unlock (objc_mutex_t mutex)
{
	int e = -1;

	if (mutex && mutex->owner == objc_thread_id())
		if (--mutex->depth == 0)
			mutex->owner = 0;

	if (mutex && ((e = pthread_mutex_unlock(&mutex->backend)) == 0))
		return mutex->depth;

//	printf("objc_mutex_unlock failed %s\n\n",strerror(e));

	return -1;
}

int
objc_mutex_deallocate (objc_mutex_t mutex)
{
	int depth = -1;

	if (mutex)								// ascertain mutex ownership by
		{									// acquiring a lock on the mutex
		depth = objc_mutex_lock(mutex);		// undefined to destroy otherwise
		pthread_mutex_destroy(&mutex->backend);
		free(mutex);
		}

	return depth;							// Return last depth (1 for dealloc)
}

objc_mutex_t
objc_mutex_allocate (int type)
{
	objc_mutex_t m = (objc_mutex_t)calloc(1, sizeof(struct objc_mutex));
	pthread_mutexattr_t ma, *a = NULL;

	switch (type)
		{
		case 2:								// NSRecursiveLock
			a = &ma;
			pthread_mutexattr_init(a);
			pthread_mutexattr_settype(a, PTHREAD_MUTEX_RECURSIVE);
		default:	break;					// NSConditionLock, NSLock
		}

	if (m && pthread_mutex_init(&m->backend, a) != 0)
    	{
        printf("\n mutex init failed\n");
		free(m);
        m = NULL;
    	}

	if (a)
		pthread_mutexattr_destroy(a);

	return m;
}

static objc_condition_t
objc_condition_allocate()
{
	pthread_cond_t *cv;			// init condition variable to default value

	if ((cv = malloc(sizeof(pthread_cond_t))))
		if (pthread_cond_init(cv, NULL))
			{
			free(cv);
			cv = NULL;
			}

	return (objc_condition_t)cv;
}

static objc_mutex_t
__mutex_alloc(int type)					{ return objc_mutex_allocate(type); }

#else  /* ! __USE_LIBOBJC2__ */

static objc_mutex_t
__mutex_alloc(int type)					{ return objc_mutex_allocate(); }

#endif

/* ****************************************************************************

	NSLock

** ***************************************************************************/

@implementation NSLock

- (id) init											// Designated initializer
{
	if ((self = [super init]) && !(_mutex = __mutex_alloc(0)))
		return _NSInitError(self, @"Failed to allocate a mutex");

	return self;
}
											// Ask the runtime to dealloc the
- (void) dealloc							// mutex.  If there are outstanding
{											// locks then it will block.
	if (objc_mutex_deallocate (_mutex) == -1)	
		[NSException raise:NSLockException format:@"invalid mutex"];

	[super dealloc];
}

- (BOOL) tryLock										// Try to acquire the
{														// lock. Does not block
	if ((_mutex)->owner == objc_thread_id())
		[NSException raise:NSLockException format:@"already locked"];

	return (objc_mutex_trylock (_mutex) == -1) ? NO : YES;
}

- (BOOL) lockBeforeDate:(NSDate *)limit			{ NIMP return NO; }

- (void) lock											// NSLocking protocol
{
	if ((_mutex)->owner == objc_thread_id())
		[NSException raise:NSLockException format:@"already locked"];
	if (objc_mutex_lock (_mutex) == -1)					// Locking may block
		[NSException raise:NSLockException format:@"failed to lock mutex"];
}

- (void) unlock
{
	if (objc_mutex_unlock (_mutex) == -1)
		[NSException raise:NSLockException 
					 format:@"unlock: failed to unlock mutex"];
}

@end /* NSLock */

/* ****************************************************************************

	NSConditionLock

	Allows locking and unlocking to be based upon an integer condition

** ***************************************************************************/

@implementation NSConditionLock

- (id) init							{ return [self initWithCondition: 0]; }

- (id) initWithCondition:(int)value					// Designated initializer 
{
	if ((self = [super init]))
		{
		_conditionValue = value;

		if (!(_condition = objc_condition_allocate()))
			return _NSInitError(self, @"Failed to allocate a condition");

		if (!(_mutex = __mutex_alloc(1)))
			return _NSInitError(self, @"Failed to allocate a mutex");
		}

	return self;
}

- (void) dealloc
{
	if (objc_condition_deallocate (_condition) != 0)
		[NSException raise:NSConditionLockException
					 format:@"dealloc: condition failed"];
	if (objc_mutex_deallocate (_mutex) == -1)		// Blocks if mutex locked
		[NSException raise:NSConditionLockException
					 format:@"dealloc: invalid mutex"];
	[super dealloc];
}

- (int) condition					{ return _conditionValue; }

- (void) lockWhenCondition:(int)value
{
	if ((_mutex)->owner == objc_thread_id())
		[NSException raise:NSConditionLockException format:@"already locked"];

	if (objc_mutex_lock(_mutex) == -1)
		[NSException raise:NSConditionLockException
					 format:@"lockWhenCondition: failed to lock mutex"];
													// Unlocks mutex while we
	while (_conditionValue != value)				// wait on the condition
		if (objc_condition_wait(_condition, _mutex) == -1)
			[NSException raise:NSConditionLockException
						 format:@"objc_condition_wait failed"];
}

- (void) unlockWithCondition:(int)value
{
	_conditionValue = value;
													// set the condition and
	if (objc_condition_broadcast(_condition))		// wake up blocked threads
		[NSException raise:NSConditionLockException
					 format:@"unlockWithCondition: condition broadcast failed"];

	if ((objc_mutex_unlock (_mutex) == -1))
		[NSException raise:NSConditionLockException
					 format:@"unlockWithCondition: failed to unlock mutex"];
}

- (BOOL) tryLock
{
	if ((_mutex)->owner == objc_thread_id())
		[NSException raise:NSConditionLockException format:@"already locked"];

	return (objc_mutex_trylock(_mutex) == -1) ? NO : YES;
}

- (BOOL) tryLockWhenCondition:(int)value
{
	if (_conditionValue == value)		// FIX ME old implementation is
		return [self tryLock];			// not compliant with Apple docs

#ifdef __USE_LIBOBJC2__
	if ([self tryLock])
		return [self lockWhenCondition:value beforeDate:nil];
#endif

	return NO;
}

- (BOOL) lockBeforeDate:(NSDate *)limit
{
#ifdef __USE_LIBOBJC2__
	struct timespec timeout = {0,0};

	if (limit)
		{
		NSTimeInterval ti = [limit timeIntervalSinceNow];

		if (ti < LONG_MAX && ti > 0.0)
			{
			timeout.tv_sec = ti;
			timeout.tv_nsec = (ti - timeout.tv_nsec) * 1000000000.0;
		}	}

	if (!(!pthread_cond_timedwait(_condition, &(_mutex)->backend, &timeout)))
		return YES;

	_mutex->owner = 0;						// reset virtual ownership of mutex
	_mutex->depth = 0;

	pthread_mutex_unlock(&(_mutex)->backend);
#endif

	return NO;
}

/* ****************************************************************************

	lockWhenCondition: beforeDate:

	Block thread’s execution until lock can be acquired or limit date is
	reached.  Receiver’s condition must equal value before lock op will
	succeed.  Returns YES if lock acquired within time limit, NO otherwise

** ***************************************************************************/

- (BOOL) lockWhenCondition:(int)value beforeDate:(NSDate *)limit
{
#ifdef __USE_LIBOBJC2__
	int e;
	struct timespec timeout = {0,0};

	if (limit)
		{
		NSTimeInterval ti = [limit timeIntervalSinceNow];

		if (ti < LONG_MAX && ti > 0.0)
			{
			timeout.tv_sec = ti;
			timeout.tv_nsec = (ti - timeout.tv_nsec) * 1000000000.0;
			}
		}		// release mutex atomically then wait on condition variable,
				// returns with mutex locked and owned by calling thread even
	do {		// when returning an error.
		e = pthread_cond_timedwait(_condition, &_mutex->backend, &timeout);
	} while (_conditionValue != value && !e);

	if (!e && _conditionValue == value)
		return YES;

	_mutex->owner = 0;						// reset virtual ownership of mutex
	_mutex->depth = 0;

	pthread_mutex_unlock(&(_mutex)->backend);
#endif

	return NO;
}

- (void) lock
{													// ignores the condition
	if ((_mutex)->owner == objc_thread_id())
		[NSException raise:NSConditionLockException format:@"already locked"];
													// Acquire a lock on mutex
	if (objc_mutex_lock (_mutex) == -1)				// This will block
		[NSException raise:NSConditionLockException
					 format:@"lock: failed to lock mutex"];
}

- (void) unlock
{													// wake up blocked threads
	if (objc_condition_broadcast(_condition))
		[NSException raise:NSConditionLockException
					 format:@"unlock: condition broadcast failed"];

	if (objc_mutex_unlock (_mutex) == -1)			// Release lock on mutex
		[NSException raise:NSConditionLockException
					 format:@"unlock: failed to unlock mutex"];
}

@end /* NSConditionLock */

/* ****************************************************************************

	NSRecursiveLock

	Allows the lock to be recursively acquired by the same thread.  If the
	same thread locks the mutex (n) times then that same thread must also
	unlock it (n) times before another thread can acquire the lock.

** ***************************************************************************/

@implementation NSRecursiveLock

+ (NSRecursiveLock *) _globalLock

{								// lock for use when operating on global mutable
	if (__globalLock == nil)	// data that may invoke methods which access it
		__globalLock = [[NSRecursiveLock alloc] init];

	return __globalLock;
}

- (id) init											// Designated initializer
{
	if ((self = [super init]) && !(_mutex = __mutex_alloc(2)))
		return _NSInitError(self, @"Failed to allocate a mutex");

	return self;
}

- (void) dealloc									// Deallocate the mutex If  
{													// there are outstanding 
	if (objc_mutex_deallocate (_mutex) == -1)		// locks then it will block
		[NSException raise:NSRecursiveLockException
					 format:@"dealloc: invalid mutex"];
	[super dealloc];
}

- (BOOL) lockBeforeDate:(NSDate *)limit		{ NIMP return NO; }

- (BOOL) tryLock									// Try to acquire lock.
{										  			// Does not block
	return (objc_mutex_trylock (_mutex) == -1) ? NO : YES;
}
													// NSLocking protocol
- (void) lock							
{													// Acquire a lock on mutex
	if (objc_mutex_lock (_mutex) == -1)				// This will block
		[NSException raise:NSRecursiveLockException
					 format:@"lock: failed to lock mutex"];
}

- (void) unlock
{
	if (objc_mutex_unlock (_mutex) == -1)			// Release lock on mutex
		[NSException raise:NSRecursiveLockException
					 format:@"unlock: failed to unlock mutex"];
}

@end /* NSRecursiveLock */
