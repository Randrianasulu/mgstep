/*
   NSNotificationQueue.m

   Queue notifications for delayed posting

   Copyright (C) 1995-2018 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of the mGSTEP Library and is provided under the 
   terms of the libFoundation BSD type license (See the Readme file).
*/

#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSThread.h>


typedef struct _QListNode {
    struct _QListNode *next;
    struct _QListNode *prev;
    id queue;
} _QList;

typedef struct  { @defs(NSNotificationQueue); } _NSNotificationQueue;


// Class variables
static _QList *__notificationQueues = NULL;
static NSNotificationQueue *__defaultQueue = nil;



@interface _NSQueueRegistration : NSObject
{
@public
    _NSQueueRegistration *next;
    _NSQueueRegistration *prev;
    NSNotification *notification;
    id name;
    id object;
    NSArray *modes;
	int countQueued;
}

@end

@implementation _NSQueueRegistration
@end

/*
	Queue List layout  (NotificationQueueList)

	Queue             Node              Node              Node

	  head ---------> prev -----------> prev -----------> prev --> nil
			  nil <-- next <----------- next <----------- next
	  tail --------------------------------------------->
*/

typedef struct _NotificationQueueList {
    _NSQueueRegistration *head;
    _NSQueueRegistration *tail;
} NotificationQueueList;


@interface NSNotification (QueueRegistration)

- (void) _addToQueue:(NotificationQueueList *)queue forModes:(NSArray *)modes;

@end


@implementation NSNotification (QueueRegistration)

- (void) _initSafe				{ _registry = [_NSQueueRegistration new]; }

- (void) _addToQueue:(NotificationQueueList *)queue forModes:(NSArray *)modes
{
	if (_registry == nil)
		_registry = [_NSQueueRegistration new];

	((_NSQueueRegistration *)_registry)->countQueued++;
	if (((_NSQueueRegistration *)_registry)->notification != nil)
		return;

	((_NSQueueRegistration *)_registry)->notification = [self retain];
	((_NSQueueRegistration *)_registry)->name = _name;
	((_NSQueueRegistration *)_registry)->object = _object;
	if (modes)
		((_NSQueueRegistration *)_registry)->modes = [modes copy];
	((_NSQueueRegistration *)_registry)->prev = NULL;
	((_NSQueueRegistration *)_registry)->next = queue->tail;
	queue->tail = _registry;

	if (((_NSQueueRegistration *)_registry)->next)
		((_NSQueueRegistration *)_registry)->next->prev = _registry;
	if (!queue->head)
		queue->head = _registry;
}		

@end


static void
_RemoveFromQueue(NotificationQueueList *queue, _NSQueueRegistration *item)
{
    if (item->prev)
		item->prev->next = item->next;
    else if ((queue->tail = item->next))
	    item->next->prev = NULL;

    if (item->next)
		item->next->prev = item->prev;
    else if ((queue->head = item->prev))
	    item->prev->next = NULL;

	if (item->modes)
		[item->modes release];
	[item->notification release];
	item->notification = nil;
	item->countQueued = 0;
}


@implementation NSNotificationQueue

+ (void) initialize
{
 	if (!__defaultQueue)
		__defaultQueue = [[self alloc] init];
}

+ (NSNotificationQueue*) defaultQueue		{ return __defaultQueue; }

- (id) init
{
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    return [self initWithNotificationCenter: nc];
}

- (id) initWithNotificationCenter:(NSNotificationCenter*)notificationCenter
{
	_QList *ri;

    _center = [notificationCenter retain];
    _asapQueue = calloc(1, sizeof(NotificationQueueList));
    _idleQueue = calloc(1, sizeof(NotificationQueueList));

    ri = calloc(1, sizeof(_QList));						// insert in global
	ri->next = __notificationQueues;					// list of queues
	ri->queue = self;
	__notificationQueues = ri;

    return self;
}

- (void) dealloc
{
	_NSQueueRegistration *item;
	_QList *queues = __notificationQueues;				// remove from class
														// instances list
    if (queues->queue == self) 
	    __notificationQueues = __notificationQueues->next;
    else 
		{
		_QList *ri, *it;

		for(ri = __notificationQueues; ri->next; ri = ri->next)
			if (ri->next->queue == self) 
				{
				it = ri->next;
				ri->next = it->next;
				free(it);
				break;
		}		}

    for (item = _asapQueue->head; item; item = item->prev)
		_RemoveFromQueue(_asapQueue, item);
    free(_asapQueue);

    for (item = _idleQueue->head; item; item=item->prev)
		_RemoveFromQueue(_idleQueue, item);
    free(_idleQueue);

    [_center release];

    [super dealloc];
}

- (void) dequeueNotificationsMatching:(NSNotification*)notification
						 coalesceMask:(NSNotificationCoalescing)mask
{												 
	_NSQueueRegistration *item;				// Inserting and Removing
	_NSQueueRegistration *next;				// Notifications From a Queue
	id name = [notification name];
	id no = [notification object];
											// find ASAP notification in queue
    for (item = _asapQueue->tail; item; item = next) 
		{
		next = item->next;
		if ((mask & NSNotificationCoalescingOnName) && [name isEqual:item->name])
			{
			_RemoveFromQueue(_asapQueue, item);
			continue;
			}
		if ((mask & NSNotificationCoalescingOnSender) && (no == item->object))
			{
			_RemoveFromQueue(_asapQueue, item);
			continue;
		}	}
											// find idle notification in queue
    for (item = _idleQueue->tail; item; item = next)
		{
		next = item->next;
		if ((mask & NSNotificationCoalescingOnName) && [name isEqual:item->name])
			{
			_RemoveFromQueue(_asapQueue, item);
			continue;
			}
		if ((mask & NSNotificationCoalescingOnSender) && (no == item->object))
			{
			_RemoveFromQueue(_asapQueue, item);
			continue;
		}	}
}

- (BOOL) postNotification:(NSNotification*)notification
		 		 forModes:(NSArray*)modes
{
	BOOL post = NO;
	NSString *mode;								// check to see if run loop is
    											// in a valid mode
    if (!modes || !(mode = [[NSRunLoop currentRunLoop] currentMode]))
		post = YES;
    else
		{
		int i = [modes count] - 1;

		for (; i >= 0; i--)
			if ([mode isEqual:[modes objectAtIndex:i]])
				{
				post = YES;
				break;
		}		}

    if (post)									// if mode is valid then post
		[_center postNotification:notification];

    return post;
}

- (void) enqueueNotification:(NSNotification*)notification
				postingStyle:(NSPostingStyle)postingStyle	
{
	[self enqueueNotification:notification
		  postingStyle:postingStyle
		  coalesceMask:NSNotificationCoalescingOnName + NSNotificationCoalescingOnSender
		  forModes:nil];
}

- (void) enqueueNotification:(NSNotification*)notification
				postingStyle:(NSPostingStyle)postingStyle
				coalesceMask:(NSNotificationCoalescing)mask
				forModes:(NSArray*)modes
{
    if (mask != NSNotificationNoCoalescing)
		[self dequeueNotificationsMatching:notification coalesceMask:mask];

    switch (postingStyle) 
		{
		case NSPostNow:
			[self postNotification:notification forModes:modes];
			break;
		case NSPostASAP:
			[notification _addToQueue:_asapQueue forModes:modes];
			break;
		case NSPostWhenIdle:
			[notification _addToQueue:_idleQueue forModes:modes];
			break;
		}
}

@end


BOOL
_RunLoopAwaitsIdle(void)
{
	_QList *n;

    for (n = __notificationQueues; n; n = n->next)
		if (((_NSNotificationQueue *)n->queue)->_idleQueue->head)
			return YES;

	return NO;
}

static void
_PostNotifications(NSNotificationQueue *nq, NotificationQueueList *ql)
{
	_NSQueueRegistration *h = ql->head;

    while (h)								// post all notifications in queue
		{
		_NSQueueRegistration *p = h->prev;
		int i = h->countQueued;

		while (i-- > 0)
		  if ([nq postNotification:h->notification forModes:h->modes] && i == 0)
			_RemoveFromQueue(ql, h);
		h = p;
		}
}

void
_PostRunLoopIdle(void)
{
	_QList *n;

    for (n = __notificationQueues; n; n = n->next)
		if (((_NSNotificationQueue *)n->queue)->_idleQueue->head)
			_PostNotifications(n->queue, ((_NSNotificationQueue *)n->queue)->_idleQueue);
}

void
_PostRunLoopASAP(void)
{
	_QList *n;
    
    for (n = __notificationQueues; n; n = n->next)
		if (((_NSNotificationQueue *)n->queue)->_asapQueue->head)
			_PostNotifications(n->queue, ((_NSNotificationQueue *)n->queue)->_asapQueue);
}
