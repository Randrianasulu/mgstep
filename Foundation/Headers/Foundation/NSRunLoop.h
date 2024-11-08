/*
   NSRunLoop.h

   Manage I/O sources and actions.

   Copyright (C) 1996-2016 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	March 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSRunLoop
#define _mGSTEP_H_NSRunLoop

#include <Foundation/NSObject.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSDate.h>

#define MAX_COMMON_RL_MODES  8

@class NSTimer;
@class NSDate;
@class NSPort;
@class NSMutableArray;

extern const id  NSDefaultRunLoopMode;						// Mode strings
extern const id  NSRunLoopCommonModes;


@interface NSRunLoop : NSObject
{
@private 
	id _currentMode;
	id _commonRunLoopModes[MAX_COMMON_RL_MODES + 1];
	NSMapTable *_mode_2_timers;
	NSMapTable *_mode_2_watchers;
	NSMutableArray *_performers;
	NSMutableArray *_timedPerformers;
	NSMapTable *_rfd_2_object;
	NSMapTable *_wfd_2_object;
}

+ (NSRunLoop*) currentRunLoop;

- (void) addPort:(NSPort*)aPort forMode:(NSString*)mode;
- (void) removePort:(NSPort*)aPort forMode:(NSString*)mode;
- (void) addTimer:(NSTimer*)timer forMode:(NSString*)mode;

- (NSString*) currentMode;
- (NSDate*) limitDateForMode:(NSString*)mode;

- (void) acceptInputForMode:(NSString*)mode beforeDate:(NSDate*)date;

- (void) run;
- (void) runUntilDate:(NSDate*)limit_date;
- (BOOL) runMode:(NSString*)mode beforeDate:(NSDate*)date;

@end


@interface NSRunLoop (OPENSTEP)

- (void) cancelPerformSelector:(SEL)aSelector
						target:(id)target
						argument:(id)argument;

- (void) performSelector:(SEL)aSelector
				  target:(id)target
				  argument:(id)argument
				  order:(unsigned int)order
				  modes:(NSArray*)modes;
@end


@interface NSObject  (TimedPerformers)

+ (void) cancelPreviousPerformRequestsWithTarget:(id)t;
+ (void) cancelPreviousPerformRequestsWithTarget:(id)t
										selector:(SEL)sel
										object:(id)arg;
- (void) performSelector:(SEL)sel
			  withObject:(id)arg
			  afterDelay:(NSTimeInterval)seconds;

- (void) performSelector:(SEL)aSelector
			  withObject:(id)argument
			  afterDelay:(NSTimeInterval)seconds
			  inModes:(NSArray*)modes;
@end


@protocol FdListening									// mGSTEP extensions

- (void) getFds:(int*)fds count:(int*)count;

@end

#endif /*_mGSTEP_H_NSRunLoop */
