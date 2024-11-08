/*
   NSRunLoop.m

   Manage I/O sources and actions.

   Copyright (C) 1996-2019 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	March 1996
   GNUstep: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	August 1997
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	April 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSPort.h>

#include <CoreFoundation/CFRunLoop.h>
#include <CoreFoundation/CFSocket.h>

#include <sys/time.h>


// Class variables
static NSThread *__currentThread = nil;
static NSRunLoop *__currentRunLoop = nil;

const id  NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";
const id  NSRunLoopCommonModes = @"NSRunLoopCommonModes";


extern void _PostRunLoopASAP(void);
extern void _PostRunLoopIdle(void);
extern BOOL _RunLoopAwaitsIdle(void);

extern NSDate *_RunLoopSourceLimitDate(CFRunLoopSourceRef rs);
extern void _RunLoopSourceInvalidate(CFRunLoopSourceRef rs);
extern id _RunLoopSourceTarget(CFRunLoopSourceRef rs);
extern int _RunLoopSourceHandle(CFRunLoopSourceRef rs);

/* ****************************************************************************

	RunLoopAction

** ***************************************************************************/

@interface RunLoopAction : NSObject		// Store message to be sent to objects
{										// once a particular runloop iteration
	SEL _selector;						// has passed.
	id _target;
	id _argument; 
	unsigned _order;
@public
	NSArray	*_modes;
	NSTimer	*_timer;
}

+ (RunLoopAction*) withSelector:(SEL)aSelector
						 target:(id)target
						 argument:(id)argument
						 order:(unsigned int)order
						 modes:(NSArray*)modes;

- (BOOL) matchesSelector:(SEL)aSelector
				  target:(id)aTarget
				  argument:(id)anArgument;
- (void) fire;
- (void) setTimer:(NSTimer*)timer;
- (NSArray*) modes;
- (unsigned int) order;

@end

/* ****************************************************************************

	NSRunLoop

** ***************************************************************************/

@interface NSRunLoop (Private)

- (NSMutableArray*) _timedPerformers;
- (id) delegate;

@end

@implementation NSRunLoop

+ (NSRunLoop *) currentRunLoop
{
	NSString *key = @"NSRunLoopThreadKey";
	NSThread *t = [NSThread currentThread];

	if(__currentThread != t)
		{
		__currentThread = t;

		if((__currentRunLoop = [[t threadDictionary] objectForKey:key]) == nil)					
			{										// if current thread has no
			__currentRunLoop = [NSRunLoop new];		// run loop create one
			[[t threadDictionary] setObject:__currentRunLoop forKey:key];
			[__currentRunLoop release];
		}	}

	return __currentRunLoop;
}

- (id) init											// designated initializer
{
	[super init];

	_mode_2_timers = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
									   NSObjectMapValueCallBacks, 0);
	_mode_2_watchers = NSCreateMapTable (NSObjectMapKeyCallBacks,
										 NSObjectMapValueCallBacks, 0);
	_rfd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
									 NSObjectMapValueCallBacks, 0);
	_wfd_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
									 NSObjectMapValueCallBacks, 0);
	_performers = [[NSMutableArray alloc] initWithCapacity:8];
	_timedPerformers = [[NSMutableArray alloc] initWithCapacity:8];
	_commonRunLoopModes[0] = NSDefaultRunLoopMode;

	return self;
}

- (void) dealloc
{
	NSFreeMapTable(_mode_2_timers);
	NSFreeMapTable(_mode_2_watchers);
	NSFreeMapTable (_rfd_2_object);
	NSFreeMapTable (_wfd_2_object);
	[_performers release];
	[_timedPerformers release];

	[super dealloc];
}

/* ****************************************************************************

	Perform one pass thru RunLoop in mode searching for earliest fire date

** ***************************************************************************/

- (NSDate *) limitDateForMode:(NSString*)mode
{
	NSMutableArray *timers;
	NSMutableArray *watchers;
	NSTimer *min_timer = nil;
	CFRunLoopSourceRef min_source = NULL;
	NSDate *when;

	_currentMode = mode;
	_PostRunLoopASAP();							// Post notifications

	if ((timers = NSMapGet(_mode_2_timers, mode)))
		{
		NSTimeInterval minTime = 0;
		NSTimer *timerWithNearestFireDate = nil;
		int i = [timers count];

		while (i-- > 0)							// Traverse list of timers for
			{									// this RunLoop mode
			min_timer = (NSTimer*)[timers objectAtIndex:i];
												// if timer is not valid remove
			if (!min_timer->_is_valid)			// it from the timers list
				[timers removeObjectAtIndex: i];
			else
				{								// get time until fire date
				NSTimeInterval tu = [[min_timer fireDate] timeIntervalSinceNow];

				if (tu <= 0)					// Firing increments the timers
					{							// fire date and can produce
					[min_timer fire];			// recursion into this method

					i = [timers count];			// restore loop sanity
					timerWithNearestFireDate = nil;
					minTime = 0;
					_currentMode = mode;
					}
				else if ((tu < minTime || minTime == 0))
					{							// detect the timer with the
					minTime = tu;				// nearest fire date
					timerWithNearestFireDate = min_timer;
			}	}	};

		min_timer = timerWithNearestFireDate;
		}										// Traverse list of rl sources
												// for this RunLoop mode
	if ((watchers = NSMapGet(_mode_2_watchers, mode)))
		{
		NSUInteger i = [watchers count];
									// cycle thru sources list until we either
		while (i-- > 0)				// run out of sources or find one with a
			{						// positive time (min since list is ordered)
			min_source = (CFRunLoopSourceRef)[watchers objectAtIndex:0];

			if (!CFRunLoopSourceIsValid(min_source))
				{							// remove invalid rl sources
				[watchers removeObjectAtIndex: 0];
				min_source = NULL;
				continue;
				}							// break out of loop if we reach
											// a source with a positive time
			when = _RunLoopSourceLimitDate(min_source);
			if ((when == nil) || [when timeIntervalSinceNow] > 0)
				break;								
			else							// else rl source is now useless,
				{							// invalidate and remove it from que
				_RunLoopSourceInvalidate(min_source);
				[watchers removeObjectAtIndex:0];
	      		min_source = NULL;
		} 	}	}							// set limit date to earliest timer
											// if there is one
	when = (min_timer) ? [min_timer fireDate] : nil;
							// alter the limit date to the earliest source or
	if (min_source)			// leave it as the date of the earliest timer if
		{					// that is before the earliest source's limit.
		NSDate *lim = _RunLoopSourceLimitDate(min_source);

		if (lim == nil)
			lim = [NSDate distantFuture];	// No limit source watches forever

		if (when == nil)
			when = lim;
		else
			when = [when earlierDate:lim];
		}

	_currentMode = nil;

	return when;
}

- (void) _checkPerformers
{
	int count = [_performers count];
	int i = 0, loop;

	for (loop = 0; loop < count; loop++)
		{
		RunLoopAction *a = [_performers objectAtIndex: i];

		if ([a->_modes containsObject: _currentMode])
			{
			[_performers removeObjectAtIndex: i];
			[a fire];
			}
		else									// inc cntr only if obj is not
			i++;								// removed else we will run off
		}										// the end of the array
}

- (void) acceptInputForMode:(NSString*)mode beforeDate:(NSDate*)limit_date
{
	NSMutableArray *watchers;
	struct timeval timeout = {0};
	struct timeval *select_timeout = &timeout;
	fd_set read_fds;							// read-ready fds
	fd_set write_fds;							// write-ready fds
	fd_set exception_fds;						// exception fds
	int select_return;
	int nfds = 0;								// highest num FD in any set +1

	NSAssert(mode, NSInvalidArgumentException);

	_currentMode = mode;						// Determine time to wait and
												// set SELECT_TIMEOUT.
	if (limit_date)								// Call select() with 0 timeout
		{										// (no wait) if no limit date
		NSTimeInterval ti = [limit_date timeIntervalSinceNow];

		if (ti <= 0.0)							// If LIMIT_DATE has already
			{									// passed, return immediately.
			[self _checkPerformers];
			DBLog(@"NSRunLoop limit date past, returning\n");
			_currentMode = nil;

			return;
			}

		if (ti < INT_MAX)
    		{									// Wait until the LIMIT_DATE.
			DBLog(@"NSRunLoop accept input %f seconds from now %f\n", 						
					[limit_date timeIntervalSinceReferenceDate], ti);

			timeout.tv_sec = ti;
			timeout.tv_usec = (ti - timeout.tv_sec) * 1000000.0;
			}
		else
			{
			DBLog(@"NSRunLoop accept input waiting forever\n");
			select_timeout = NULL;
			}
		}

	FD_ZERO (&read_fds);						// Initialize the set of FDS
	FD_ZERO (&write_fds);						// we'll pass to select()

	if ((watchers = NSMapGet(_mode_2_watchers, mode)))
		{										// Do the pre-listening set-up
		int	k = [watchers count];				// for the file descriptors of
												// this mode.
		while (k-- > 0)
			{
			CFRunLoopSourceRef e = (CFRunLoopSourceRef)[watchers objectAtIndex:k];
			CFOptionFlags f = _RunLoopSourceGetCallbackTypes(e);
			int fd = _RunLoopSourceHandle(e);

			if (!CFRunLoopSourceIsValid(e))
				{
				[watchers removeObjectAtIndex: k];
				continue;
				}

			if ((f & kCFSocketWriteCallBack) || (f & kCFSocketConnectCallBack))
				{
				FD_SET (fd, &write_fds);
				NSMapInsert (_wfd_2_object, INT2PTR(fd), e);
				nfds = MAX(fd + 1, nfds);
				}
			if ((f & kCFSocketReadCallBack))
				{
				FD_SET (fd, &read_fds);
				NSMapInsert (_rfd_2_object, INT2PTR(fd), e);
				nfds = MAX(fd + 1, nfds);
				}
			if ((f & kCFSocketReadCallBack) || (f & kCFSocketAcceptCallBack))
				{
				int num_ports = 128;	// FIX ME #define this constant
				int port_fd_array[num_ports];
				id port = _RunLoopSourceTarget(e);

				if ([port respondsToSelector: @selector(getFds:count:)])
					[port getFds: port_fd_array count: &num_ports];
				else
					num_ports = 0;
				DBLog(@"NSRunLoop listening to %d sockets\n", num_ports);

				while (num_ports--)
					{
					fd = port_fd_array[num_ports];
					FD_SET (fd, &read_fds);
					NSMapInsert (_rfd_2_object, INT2PTR(fd), e);
					nfds = MAX(fd + 1, nfds);
					}
				}
		}	};

	exception_fds = read_fds;

	if (nfds == 0 && _RunLoopAwaitsIdle())		// Detect if have idle in Q
		{
		timeout.tv_sec = 0;
		timeout.tv_usec = 0;
		select_timeout = &timeout;
		}

	select_return = select( nfds,				// max of FD_SETSIZE check ?
							&read_fds,
							&write_fds,
							&exception_fds,
							select_timeout);

	DBLog(@"NSRunLoop select returned %d\n", select_return);

	if (select_return < 0)
		{
		if (errno == EINTR)							// a signal was caught
			select_return = 0;
		else										// Some kind of exceptional
			{										// condition has occurred
			if (errno != EBADF)
				abort();							// abort if not stale fd
			perror("*** NSRunLoop acceptInputForMode:beforeDate: in select()");
			select_return = 0;
		}	}

	if (select_return == 0)			// Detect an idle NSRunLoop
		_PostRunLoopIdle();
	else							// Inspect all file descriptors select()
		{							// says are ready, notify the respective
		int fd_index = 0;			// object for each ready fd.
		CFRunLoopSourceRef rs;

		for (; fd_index < nfds; fd_index++)
			{
			if (FD_ISSET (fd_index, &write_fds))
				{
				rs = NSMapGet(_wfd_2_object, INT2PTR(fd_index));
				NSAssert(rs, NSInternalInconsistencyException);
				_RunLoopSourceWriteReady(rs, fd_index);
				}

			if (FD_ISSET (fd_index, &read_fds))
				{
				rs = NSMapGet(_rfd_2_object, INT2PTR(fd_index));
				NSAssert(rs, NSInternalInconsistencyException);
				_RunLoopSourceReadReady(rs, fd_index);
		}	}	}

	_PostRunLoopASAP();

	NSResetMapTable (_rfd_2_object);				// Clean up before return
	NSResetMapTable (_wfd_2_object);
	[self _checkPerformers];
	_currentMode = nil;
}

- (BOOL) runMode:(NSString*)mode beforeDate:(NSDate*)date
{
	id d;

	if ([date timeIntervalSinceNow] < 0)			// If date has already
		{											// passed, simply return
		DBLog(@"NSRunLoop attempted to run mode with past date\n");
		return NO;
		}
													// Determine time to wait 
	if ((d = [self limitDateForMode: mode]) == nil)	// before first limit date
		{
		DBLog(@"NSRunLoop run mode with nothing to do\n");
		return NO;
		}
													// Use earlier of two dates
	d = [[d earlierDate:date] retain];
	[self acceptInputForMode:mode beforeDate:d];	// Wait listening to sources
	[d release];

	return YES;
}

- (void) runUntilDate:(NSDate*)date
{
	volatile double ti = [date timeIntervalSinceNow];
	BOOL doMore = YES;

	while (ti > 0 && doMore == YES)						// Positive values are 
		{												// in the future.
		id pool = [NSAutoreleasePool new];

		DBLog(@"NSRunLoop run until date %f seconds from now\n", ti);

		doMore = [self runMode:NSDefaultRunLoopMode beforeDate:date];
		[pool release];
		ti = [date timeIntervalSinceNow];
		}
}

- (void) run							{ [self runUntilDate: [NSDate distantFuture]]; }
- (NSString *) currentMode				{ return _currentMode; } // nil when !running
- (NSMutableArray *) _timedPerformers	{ return _timedPerformers; }

- (void) cancelPerformSelector:(SEL)aSelector
						target:target
						argument:argument
{
	int i = [_performers count];

	[target retain];
	[argument retain];

	while(i-- > 0)
		{
		RunLoopAction *a = [_performers objectAtIndex:i];

		if ([a matchesSelector:aSelector target:target argument:argument])
			[_performers removeObjectAtIndex:i];
		}

	[argument release];
	[target release];
}

- (void) performSelector:(SEL)aSelector
				  target:target
				  argument:argument
				  order:(unsigned int)order
				  modes:(NSArray*)modes
{
	int i, count;
	RunLoopAction *a = [RunLoopAction withSelector: aSelector
									  target: target
									  argument: argument
									  order: order
									  modes: modes];

	if ((count = [_performers count]) == 0)			// Add new item to list - 
		[_performers addObject: a];					// reverse ordering
	else
		{
		for (i = 0; i < count; i++)
			{
			if ([[_performers objectAtIndex:i] order] <= order)
				{
				[_performers insertObject:a atIndex:i];
				break;
			}	}

		if (i == count)
			[_performers addObject:a];
		}
}

- (void) addPort:(NSPort*)port forMode:(NSString*)mode
{
	[port scheduleInRunLoop:self forMode:mode];
}

- (void) removePort:(NSPort*)port forMode:(NSString*)mode
{
	[port removeFromRunLoop:self forMode:mode];
}

- (void) addTimer:(NSTimer *)timer forMode:(NSString*)mode
{
	NSMutableArray *timers = NSMapGet(_mode_2_timers, mode);

	if (!timers)									// Add timer. It is removed
		{											// when it becomes invalid
		timers = [NSMutableArray new];
		NSMapInsert (_mode_2_timers, mode, timers);
		[timers release];
		}				
													// FIX ME Should we make  
	[timers addObject: timer];						// sure it isn't already 
}													// there?

@end  /* NSRunLoop */


@implementation RunLoopAction

+ (RunLoopAction*) withSelector:(SEL)aSelector
						 target:(id)target
						 argument:(id)argument
						 order:(unsigned int)order
						 modes:(NSArray*)modes
{
	RunLoopAction *a = (RunLoopAction*)NSAllocateObject(self);

	a->_selector = aSelector;
	a->_target = [target retain];
	a->_argument = [argument retain];
	a->_order = order;
	a->_modes = [modes copy];

	return a;
}

- (void) dealloc
{
	DBLog(@"RunLoopAction dealloc %x  with target %x", self, _target);

	[_timer invalidate];
	[_target release];
	[_argument release];
	[_modes release];

	[super dealloc];
}

- (void) fire
{
	DBLog(@"RunLoopAction fire self %x  with target %x", self, _target);

	[_target performSelector:_selector withObject:_argument];

	if (_timer != nil)
		{
		_timer = nil;
		[[[NSRunLoop currentRunLoop] _timedPerformers]
									 removeObjectIdenticalTo: self];
		[self autorelease];
		}
}

- (void) invalidate
{
	[_timer invalidate];
	_timer = nil;
}

- (BOOL) matchesSelector:(SEL)aSelector target:(id)target argument:(id)arg
{
	if (aSelector != 0 && (_selector != aSelector))
		return NO;
	if (arg != nil && ![_argument isEqual:arg])
		return NO;
	if ((_target == target) && (_timer == nil || (_timer && _timer->_is_valid)))
		return YES;					// only matches valid (active) actions

	return NO;
}

- (NSArray*) modes						{ return _modes; }
- (unsigned int) order					{ return _order; }
- (void) setTimer:(NSTimer*)t			{ _timer = t; }

@end  /* RunLoopAction */

/* ****************************************************************************

	NSObject (TimedPerformers)

** ***************************************************************************/

@implementation NSObject (TimedPerformers)

+ (void) cancelPreviousPerformRequestsWithTarget:(id)target
										selector:(SEL)aSelector
										  object:(id)arg
{
	NSMutableArray *tp = [[NSRunLoop currentRunLoop] _timedPerformers];
	int i = [tp count];

	while(i-- > 0)
		{
		RunLoopAction *a = [tp objectAtIndex: i];

		if ([a matchesSelector:aSelector target:target argument:arg])
			{
			[a invalidate];
			[tp removeObjectAtIndex: i];
			[a release];
		}	}
}

+ (void) cancelPreviousPerformRequestsWithTarget:(id)t
{
	[self cancelPreviousPerformRequestsWithTarget:t selector:0 object:nil];
}

- (void) performSelector:(SEL)aSelector
			  withObject:(id)argument
			  afterDelay:(NSTimeInterval)seconds
			  inModes:(NSArray*)modes
{
	NSRunLoop *rl = [NSRunLoop currentRunLoop];
	RunLoopAction *a = [RunLoopAction withSelector: aSelector
									  target: self
									  argument: argument
									  order: 0
									  modes: nil];
	NSTimer *timer = [NSTimer timerWithTimeInterval: seconds
							  target: a
							  selector: @selector(fire)
							  userInfo: nil
							  repeats: NO];
	[a setTimer: timer];
	[[rl _timedPerformers] addObject: a];

	if (modes)
		{
		int i, count = [modes count];

		for (i = 0; i < count; i++)
			[rl addTimer:timer forMode: [modes objectAtIndex: i]];
		}
	else
		[rl addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void) performSelector:(SEL)aSel
	      	  withObject:(id)arg
	      	  afterDelay:(NSTimeInterval)seconds
{
	[self performSelector:aSel withObject:arg afterDelay:seconds inModes:nil];
}

@end  /* NSObject (TimedPerformers) */
