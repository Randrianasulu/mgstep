/*
   NSTimer.h

   Interface to NSTimer

   Copyright (C) 1995-2016 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	1995

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSTimer
#define _mGSTEP_H_NSTimer

#include <Foundation/NSDate.h>

@class NSInvocation;


@interface NSTimer : NSObject
{
	unsigned int _repeats:2;
	unsigned int _reserved:6;

	NSDate *_fireDate;
	NSTimeInterval _interval;

	id _info;
	id _target;
	SEL _selector;

@public
	BOOL _is_valid;
}

+ (NSTimer*) scheduledTimerWithTimeInterval:(NSTimeInterval)interval
								 invocation:(NSInvocation *)invocation
								 repeats:(BOOL)flag;

+ (NSTimer*) scheduledTimerWithTimeInterval:(NSTimeInterval)interval
									 target:(id)object
									 selector:(SEL)selector
									 userInfo:(id)info
									 repeats:(BOOL)flag;

+ (NSTimer*) timerWithTimeInterval:(NSTimeInterval)interval
						invocation:(NSInvocation *)invocation
						repeats:(BOOL)flag;

+ (NSTimer*) timerWithTimeInterval:(NSTimeInterval)interval
							target:(id)object
							selector:(SEL)selector
							userInfo:(id)info
							repeats:(BOOL)flag;
- (void) fire;
- (void) invalidate;
- (BOOL) isValid;

- (NSDate *) fireDate;
- (void) setFireDate:(NSDate *)date;

- (id) userInfo;
- (NSTimeInterval) timeInterval;

@end


@interface NSTimer (NotImplemented)

- (id) initWithFireDate:(NSDate *)date
			   interval:(NSTimeInterval)interval
			   target:(id)target
			   selector:(SEL)sel
			   userInfo:(id)info
			   repeats:(BOOL)flag;
@end

#endif /* _mGSTEP_H_NSTimer */
