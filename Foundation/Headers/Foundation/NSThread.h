/* 
   NSThread.h

   Object representing a context of execution within a shared memory space

   Copyright (C) 1996 Free Software Foundation, Inc.

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/ 

#ifndef _mGSTEP_H_NSThread
#define _mGSTEP_H_NSThread

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>


@class NSMutableDictionary;
@class NSDate;


typedef enum
{
	NSInteractiveThreadPriority,
	NSBackgroundThreadPriority,
	NSLowThreadPriority

} NSThreadPriority;


@interface NSThread : NSObject
{
	NSMutableDictionary *_dictionary;
	id _target;
	SEL _selector;

@public
	NSHandler *_exception_handler;
	struct autorelease_thread_vars _autorelease_vars;
}

+ (NSThread*) currentThread;
+ (void) detachNewThreadSelector:(SEL)aSelector
						toTarget:(id)aTarget
						withObject:(id)anArgument;
+ (BOOL) isMultiThreaded;
+ (void) sleepUntilDate:(NSDate*)date;
+ (void) exit;

- (NSMutableDictionary*) threadDictionary;

@end

extern NSString *NSBecomingMultiThreaded;					// Notifications
extern NSString *NSThreadExiting;

#endif /* _mGSTEP_H_NSThread */
