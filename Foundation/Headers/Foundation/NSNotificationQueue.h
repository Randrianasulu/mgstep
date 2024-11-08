/*
   NSNotificationQueue.h

   Copyright (C) 1995-2016 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#ifndef _mGSTEP_H_NSNotificationQueue
#define _mGSTEP_H_NSNotificationQueue

#include <Foundation/NSNotification.h>

@class NSArray;


typedef enum {
    NSPostWhenIdle = 1,
    NSPostASAP     = 2,
    NSPostNow      = 3
} NSPostingStyle;

typedef enum {
    NSNotificationNoCoalescing		 = 0,
    NSNotificationCoalescingOnName	 = 1,
    NSNotificationCoalescingOnSender = 2,
} NSNotificationCoalescing;


@interface NSNotificationQueue : NSObject
{
    NSNotificationCenter *_center;
    struct _NotificationQueueList *_asapQueue;
    struct _NotificationQueueList *_idleQueue;
}

+ (NSNotificationQueue*) defaultQueue;

- (id) initWithNotificationCenter:(NSNotificationCenter*)notificationCenter;
- (id) init;

- (void) dequeueNotificationsMatching:(NSNotification*)notification
						 coalesceMask:(NSNotificationCoalescing)coalesceMask;

- (void) enqueueNotification:(NSNotification*)notification
				postingStyle:(NSPostingStyle)postingStyle;

- (void) enqueueNotification:(NSNotification*)notification
				postingStyle:(NSPostingStyle)postingStyle
				coalesceMask:(NSNotificationCoalescing)coalesceMask
				forModes:(NSArray*)modes;
@end


@interface NSNotification (QueSafeSignalHandling)

- (void) _initSafe;						// prep for queueing in signal handler

@end

#endif /* _mGSTEP_H_NSNotificationQueue */
