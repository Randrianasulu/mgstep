/*
   NSLock.h

   Locking protocol and classes

   Copyright (C) 1996-2017 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date:    1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSLock
#define _mGSTEP_H_NSLock

#include <Foundation/NSObject.h>
#include <Foundation/NSDate.h>


@protocol NSLocking										// NSLocking protocol

- (void) lock;
- (void) unlock;

@end


#ifdef __USE_LIBOBJC2__

  #include <pthread.h>

  typedef pthread_t		  objc_thread_t;
  typedef pthread_cond_t  *objc_condition_t;

  typedef struct objc_mutex			// a mutual exclusion lock
  {
	objc_thread_t owner;			// owning thread identifier
	pthread_mutex_t backend;		// underlying lock
	volatile int depth;				// count of acquires

  } *objc_mutex_t;

  int objc_mutex_lock (objc_mutex_t mutex);
  int objc_mutex_unlock (objc_mutex_t mutex);

#endif


@interface NSLock : NSObject  <NSLocking>
{
	objc_mutex_t _mutex;
}

- (BOOL) tryLock;
- (BOOL) lockBeforeDate:(NSDate *)limit;

- (void) lock;
- (void) unlock;

@end


@interface NSConditionLock : NSObject  <NSLocking>
{
	objc_mutex_t _mutex;							// Allows locking and
	objc_condition_t _condition;					// unlocking to be based
	int _conditionValue;							// upon a condition
}

- (id) initWithCondition:(int)value;

- (int) condition;									// condition of the lock

- (void) lockWhenCondition:(int)value;				// Acquire / release lock
- (void) unlockWithCondition:(int)value;
- (BOOL) tryLock;
- (BOOL) tryLockWhenCondition:(int)value;

- (BOOL) lockBeforeDate:(NSDate *)limit;			// Acquiring the lock with 
- (BOOL) lockWhenCondition:(int)condition			// a date condition
				beforeDate:(NSDate *)limit;

- (void) lock;										// NSLocking protocol
- (void) unlock;

@end


@interface NSRecursiveLock : NSObject  <NSLocking>
{
	objc_mutex_t _mutex;		// mutex that can be recursively acquired
}								// by the same thread.  A thread that locks a
								// mutex n times must also unlock it n times
- (BOOL) tryLock;				// before another thread can acquire the lock.
- (BOOL) lockBeforeDate:(NSDate *)limit;

- (void) lock;										// NSLocking protocol
- (void) unlock;

@end

#endif /* _mGSTEP_H_NSLock */
