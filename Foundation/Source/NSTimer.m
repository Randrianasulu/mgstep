/*
   NSTimer.m

   Implementation of NSTimer

   Copyright (C) 1995-2016 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	March 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSTimer.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSInvocation.h>


@implementation NSTimer

+ (NSTimer*) timerWithTimeInterval:(NSTimeInterval)seconds
						invocation:(NSInvocation *)invocation
						repeats:(BOOL)f
{
	NSTimer *t = [self alloc];

	t->_interval = (seconds <= 0) ? 0.01 : seconds;
	t->_fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow: seconds];
	t->_is_valid = YES;
	t->_target = [invocation retain];
	t->_repeats = f;

	return [t autorelease];
}

+ (NSTimer*) timerWithTimeInterval:(NSTimeInterval)seconds
							target:(id)object
							selector:(SEL)selector
							userInfo:(id)info
							repeats:(BOOL)f
{
	NSTimer *t = [self alloc];

	t->_interval = (seconds <= 0) ? 0.01 : seconds;
	t->_fireDate = [[NSDate alloc] initWithTimeIntervalSinceNow: seconds];
	t->_is_valid = YES;
	t->_selector = selector;
	t->_target = [object retain];
	t->_info = [info retain];
	t->_repeats = f;

	return [t autorelease];
}

+ (NSTimer*) scheduledTimerWithTimeInterval:(NSTimeInterval)ti
								 invocation:(NSInvocation *)inv
								 repeats:(BOOL)f
{
	NSTimer *t = [self timerWithTimeInterval:ti invocation:inv repeats:f];

	[[NSRunLoop currentRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];

	return t;
}

+ (NSTimer*) scheduledTimerWithTimeInterval:(NSTimeInterval)ti
									 target:(id)object
									 selector:(SEL)selector
									 userInfo:(id)info
									 repeats:(BOOL)f
{
	NSTimer *t = [self timerWithTimeInterval: ti
					   target: object
					   selector: selector
					   userInfo: info
					   repeats: f];

	[[NSRunLoop currentRunLoop] addTimer:t forMode:NSDefaultRunLoopMode];

	return t;
}

- (void) dealloc
{
	DBLog(@"timer dealloc %x  target %x  info %x", self, _target, _info);

	[_target release], 		_target = nil;
	[_info release], 		_info = nil;
	[_fireDate release],	_fireDate = nil;
	[super dealloc];
}

- (void) fire
{
	DBLog(@"timer %x fire  rep %d isValid %d", self, _repeats, _is_valid);

	if (!_repeats)
		_is_valid = NO;
	else if (_is_valid)
		{
		NSTimeInterval ti = [_fireDate timeIntervalSinceReferenceDate];
		NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];

		NSAssert(now < 0.0, NSInternalInconsistencyException);

		while (ti < now)						// FIX ME remove this
			ti += _interval;
		[_fireDate autorelease];
		_fireDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate: ti];
		}

	if (_selector)
		[_target performSelector: _selector withObject: self];
	else
		[_target invoke];	
}

- (void) invalidate
{
	id target = _target;						// do recursion safe release
	id info = _info;

	_target = _info = nil;
	_is_valid = NO;
	[target release];							// avoid retain cycles
	[info release];
}

- (BOOL) isValid						{ return _is_valid; }
- (NSDate *) fireDate					{ return _fireDate; }
- (void) setFireDate:(NSDate *)date		{ ASSIGN(_fireDate, date); }
- (id) userInfo							{ return _info; }
- (NSTimeInterval) timeInterval			{ return _interval; }

- (int) compare:(NSTimer*)anotherTimer
{
    return [_fireDate compare: anotherTimer->_fireDate];
}

@end
