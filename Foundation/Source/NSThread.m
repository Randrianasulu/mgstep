/*
   NSThread.m

   Execution context within a shared memory space

   Copyright (C) 1996-2017 Free Software Foundation, Inc.

   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	April 2017

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSThread.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>


NSString *NSBecomingMultiThreaded = @"NSBecomingMultiThreadedNotification";
NSString *NSThreadExiting         = @"NSThreadExitingNotification";

static BOOL __hasEverBeenMultiThreaded = NO;


#ifdef __USE_LIBOBJC2__

static pthread_key_t __objc_thread_storage;

static int          __threads_alive = 1;
static objc_mutex_t __threads_mutex = 0;

struct _thread_init_state
{
	SEL selector;
	id object;
	id argument;
};

extern objc_mutex_t objc_mutex_allocate (int type);


int objc_thread_set_data (void *value)	// set thread's local storage pointer.
{										// returns 0 on success
	return pthread_setspecific(__objc_thread_storage, value);
}

void * objc_thread_get_data (void)		// return thread's local storage ptr
{										// returns NULL on failure
	return pthread_getspecific(__objc_thread_storage);
}

int
objc_thread_exit (void)
{
	objc_mutex_lock (__threads_mutex);
	__threads_alive--;
	objc_mutex_unlock (__threads_mutex);

	pthread_exit(NULL);					// Terminate the current tread

	return 0;
}

static void __attribute__((noreturn))
_thread_detach_function (struct _thread_init_state *s)
{
	id (*imp) (id, SEL, id);
	SEL selector = s->selector;
	id object   = s->object;
	id argument = s->argument;

	free (s);
	objc_thread_set_data (NULL);		// Clear out the thread local storage

	if ((imp = (id (*) (id, SEL, id))objc_msg_lookup (object, selector)))
		(*imp) (object, selector, argument);		// invoke detach method
	else
		printf ("objc_thread_detach called with bad selector.\n");
	
	objc_thread_exit ();
	
	__builtin_trap ();								// Mandate no return
}

/* ****************************************************************************

	Detach a new thread of execution. Return thread id or NULL on failure.
	Thread is started by sending a message with a single argument to object.

** ***************************************************************************/

objc_thread_t
objc_thread_detach (SEL selector, id object, id argument)
{
	struct _thread_init_state *s;
	pthread_t thread_id = 0;

	if (!(s = (struct _thread_init_state *)malloc(sizeof (*s))))
		return 0;
  
	s->selector = selector;				// init msg args structure
	s->object = object;
	s->argument = argument;

	if (!__threads_mutex)
		__threads_mutex = objc_mutex_allocate (2);
	objc_mutex_lock (__threads_mutex);

	if (!pthread_create(&thread_id, NULL, (void *)_thread_detach_function, s))
		{
		if (!pthread_detach(thread_id))
			__threads_alive++;				// count threads
		else
			printf("pthread_detach failed %s\n", strerror(errno));
		}
	else
		printf("pthread_create failed %s\n", strerror(errno));

	objc_mutex_unlock (__threads_mutex);

	return thread_id;
}

#endif  /* __USE_LIBOBJC2__ */


@interface NSRecursiveLock  (_NSGlobalMutableDataLock)

+ (NSRecursiveLock *) _globalLock;

@end

@implementation NSThread

+ (NSThread *) currentThread		{ return (id) objc_thread_get_data(); }
+ (BOOL) isMultiThreaded			{ return __hasEverBeenMultiThreaded; }

- (void) _detachThread:(id)anArgument
{
	id (*imp)(id,SEL,id);

	objc_thread_set_data(self);
	_autorelease_vars.current_pool = [NSAutoreleasePool new];

	if ((imp = (id(*)(id, SEL, id))objc_msg_lookup(_target, _selector)))
		(*imp)(_target, _selector, anArgument);
	else
		NSLog(@"Unable to call thread detach method");	// FIX ME exception
}

+ (void) detachNewThreadSelector:(SEL)aSelector
						toTarget:(id)aTarget
						withObject:(id)anArgument		// Have the runtime
{										 				// detach the thread
	NSThread *t = [NSThread new];

	t->_target = aTarget;
	t->_selector = aSelector;
										// Post note if this is first thread
	if (!__hasEverBeenMultiThreaded)	// Won't work properly if threads are
		{								// not all created by the objc runtime.
		__hasEverBeenMultiThreaded = YES;

		[NSNotificationCenter post: NSBecomingMultiThreaded object: nil];
		}

	if (objc_thread_detach(@selector(_detachThread:), t, anArgument) == 0)
		NSLog(@"Unable to detach thread (unknown error)");	// FIX ME exception
}

+ (void) sleepUntilDate:(NSDate *)date					// delay is the number
{														// of seconds remaining
	NSTimeInterval delay = [date timeIntervalSinceNow];	// in our sleep period

	for (; delay > 0; delay = [date timeIntervalSinceNow])
		sleep( delay > (30.0 * 60.0) ? 30 * 60 : delay );  // max 30 min cycles
}

+ (void) exit											// Terminate thread
{
	NSThread *t = [NSThread currentThread];

	[[NSRecursiveLock _globalLock] lock];
	[NSNotificationCenter post:NSThreadExiting object:t];
	[t release];										// Release thread obj
	[[NSRecursiveLock _globalLock] unlock];

	objc_thread_exit();									// Ask the runtime to
}														// exit the thread

- (void) dealloc
{
	_autorelease_vars.thread_in_dealloc = YES;
	while((_autorelease_vars.current_pool))
		[_autorelease_vars.current_pool dealloc];
	[_dictionary release];
	[super dealloc];
}

- (NSMutableDictionary *) threadDictionary
{
	return (_dictionary) ? _dictionary
						 : (_dictionary = [NSMutableDictionary new]);
}

@end
