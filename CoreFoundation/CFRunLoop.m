/*
   CFRunLoop.m

   Manage I/O sources and actions.

   Copyright (C) 2009-2019 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <CoreFoundation/CFRunLoop.h>

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSThread.h>

#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <time.h>
#include <sys/time.h>
#include <fcntl.h>

#define CF_SOCKET_CALLBACK(TYPE)	(*(CFSocketCallBack)rs->action) \
					(rs->socket, TYPE, NULL, INT2PTR(fd_index), rs->target)


const CFStringRef kCFRunLoopCommonModes = (CFStringRef)@"NSRunLoopCommonModes";
const CFStringRef kCFRunLoopDefaultMode = (CFStringRef)@"NSDefaultRunLoopMode";


/* ****************************************************************************

	RunLoopSource

** ***************************************************************************/

@interface RunLoopSource : NSObject
{
@public
	bool _isValid;			// if unset watcher s/b disabled on next iteration

	void *source;			// fd/resource/event watcher is interested in
	id target;				// object to be informed when fd (data) occurs
	SEL action;

	IMP msg;
	NSDate *limit;			// date at which this watcher becomes invalid

	CFRunLoopSourceContext context;
	CFSocketRef socket;
	CFIndex order;
}

@end

@implementation	RunLoopSource

- (void) dealloc
{
	_isValid = NO;
	[limit release];
	[target release];
	[super dealloc];
}

@end

typedef struct _CFRunLoopSource  { @defs(RunLoopSource); } CFRunLoopSource;
typedef struct _CFRunLoop        { @defs(NSRunLoop); }     CFRunLoop;


static void
RunLoopSourceInit(RunLoopSource *rs, SEL action, CFSocket *s)
{
	CFSocketContext *cx = s->context;

	rs->_isValid = YES;
	rs->target = [(id)rs->context.info retain];
	rs->source = INT2PTR(s->sd);
	rs->socket = (CFSocketRef)s;
	if ((rs->action = action) != NULL && cx->version == 0)	   // v0 source
		rs->msg = [rs->target methodForSelector: rs->action];
}

static void
RunLoopSourceRelease(RunLoopSource *rs)
{
	id target = rs->target;

	rs->target = nil;
	rs->source = (void *)-1;
	rs->_isValid = NO;				// RunLoop will remove during next cycle
	[target release];
}

static int
SocketConnectStatus (RunLoopSource *rs)
{
	int	r;
	int sd = PTR2INT(rs->source);
	unsigned int len = sizeof(r);

	if (getsockopt(sd, SOL_SOCKET, SO_ERROR, &r, &len) < 0)
		NSLog(@"Error in getsockopt()  (%d) %s", errno, strerror(errno));
	else if (r != 0)
		NSLog(@"NSRunLoop socket CONNECT error status (%d)", r);

	return r;						// SInt32 on error
}

static void
SocketAccept (RunLoopSource *rs)
{
	CFSocketNativeHandle sd = CFSocketGetNative(rs->socket);
	CFSocketNativeHandle h;
	struct sockaddr addr;
	unsigned int size = sizeof(addr);

	if ((h = accept(sd, &addr, &size)) < 0)
		NSLog(@"NSRunLoop ACCEPT error status (%d) %s", errno, strerror(errno));
	else
		{
		CFSocketCallBack cb = (CFSocketCallBack)rs->action;
		CFSocket s = {0};

		s.sd = h;
		if (_CFSocketSetNonBlocking(&s) < 0)
			close(h);
		else
			(*cb)(rs->socket, kCFSocketAcceptCallBack, NULL, &h, rs->target);
		}
}

CFOptionFlags _RunLoopSourceGetCallbackTypes(RunLoopSource *rs)
{
	return ((CFSocket *)rs->socket)->callBackTypes;
}

CFOptionFlags _RunLoopSourceGetFlags(RunLoopSource *rs)
{
	return ((CFSocket *)rs->socket)->flags;
}

void
_RunLoopSourceWriteReady(RunLoopSource *rs, int fd_index)
{
	CFSocketCallBackType t = (kCFSocketWriteCallBack | kCFSocketConnectCallBack);
	CFOptionFlags f = _RunLoopSourceGetCallbackTypes(rs);

	if (rs->_isValid && (f & t))
		{
		if (rs->msg)							// old school objc
			(*rs->msg)(rs->target, rs->action, rs);
		else									// CF socket port
			{
			if (f & kCFSocketConnectCallBack)	// always oneshot
				{
				CFSocketDisableCallBacks (rs->socket, kCFSocketConnectCallBack);
				if (!(f & kCFSocketDataCallBack))
					rs->_isValid = NO;			// no read callbacks
				fd_index = SocketConnectStatus (rs);
				}
			CF_SOCKET_CALLBACK((f & t));
		}	}
}

void
_RunLoopSourceReadReady(RunLoopSource *rs, int fd_index)
{
	CFOptionFlags f = _RunLoopSourceGetCallbackTypes(rs);

	if (rs->_isValid && (f & kCFSocketDataCallBack))
		{
		if (rs->msg)							// old school objc
			(*rs->msg)(rs->target, rs->action, rs);
		else									// CF socket port
			{
			CFOptionFlags reenable = _RunLoopSourceGetFlags(rs);
												// disable oneshot callbacks
			if ((f & reenable) != (f & kCFSocketDataCallBack))
				{
				if (!(f & (kCFSocketWriteCallBack | kCFSocketConnectCallBack)))
					rs->_isValid = NO;
				CFSocketDisableCallBacks (rs->socket, (f & kCFSocketDataCallBack));
				}

			if ((f & kCFSocketAcceptCallBack))
				SocketAccept (rs);
			else								// kCFSocketReadCallBack
				CF_SOCKET_CALLBACK((f & kCFSocketDataCallBack));
//			else if ((f & kCFSocketDataCallBack))
//				CFData with incoming data
		}	}
}

int _RunLoopSourceHandle(RunLoopSource *rs)	 		{ return PTR2INT(rs->source); }
id  _RunLoopSourceTarget(RunLoopSource *rs)			{ return rs->target; }
void _RunLoopSourceInvalidate(RunLoopSource *rs)	{ rs->_isValid = NO; }
NSDate *_RunLoopSourceLimitDate(RunLoopSource *rs)	{ return rs->limit; }

/* ****************************************************************************

		NSRunLoop  (mGSTEP extension)

** ***************************************************************************/

@interface NSRunLoop  (MiniCoreFoundationPrivate)

- (void) _addSource:(RunLoopSource*)rs forMode:(NSString*)mode;
- (RunLoopSource*) _getSource:(void*)source forMode:(NSString*)mode;

- (id) delegate;

@end

@implementation NSRunLoop  (MiniCoreFoundation)

- (RunLoopSource*) _getSource:(void*)source forMode:(NSString*)mode
{
	if (mode != nil)
		{
		NSArray *watchers = NSMapGet(_mode_2_watchers, mode);
		NSUInteger i, count;

		if (watchers != nil && (count = [watchers count]))
			for (i = 0; i < count; i++)
				{
				RunLoopSource *e = [watchers objectAtIndex: i];

				if (e->source == source)
					return e;
		}		}

	return nil;
}

- (void) _addSource:(RunLoopSource*)rs forMode:(NSString*)mode
{										
	NSMutableArray *watchers;			// Add a watcher to the list for the
	NSDate *limit;						// specified mode.  Keep the list in
	NSUInteger i, count = 0;			// limit-date order.

	if ((watchers = NSMapGet(_mode_2_watchers, mode)) == nil)
		{
		watchers = [NSMutableArray new];
		NSMapInsert (_mode_2_watchers, mode, watchers);
		[watchers release];
		}
	else
		count = [watchers count];

	if ([rs->target respondsToSelector: @selector(limitDateForMode:)])
		{
		NSDate *d = [rs->target limitDateForMode: mode];
									// If the target or its delegate (if any)
		ASSIGN(rs->limit, d);		// respond to limitDateForMode: then we ask
		}							// them for the limit date of this watcher
	else
		if ([rs->target respondsToSelector: @selector(delegate)])
			{
			id obj = [rs->target delegate];

			if ([obj respondsToSelector: @selector(limitDateForMode:)])
				{
				NSDate *d = [obj limitDateForMode: mode];

				ASSIGN(rs->limit, d);
			}	}

	limit = rs->limit;

	if (limit == nil || count == 0)			// Makes sure that the sources in 
		[watchers addObject:rs];			// the watchers list are ordered.
	else
		{
		for (i = 0; i < count; i++)
			{
			RunLoopSource *watcher = [watchers objectAtIndex: i];
			NSDate *when = watcher->limit;

			if (when == nil || [limit earlierDate:when] == when)
				{
				[watchers insertObject:rs atIndex:i];
				break;
			}	}

		if (i == count)
			[watchers addObject:rs];
		}
}

@end

/* ****************************************************************************

		CFRunLoop

** ***************************************************************************/

CFRunLoopRef
CFRunLoopGetCurrent (void)
{
	return (CFRunLoopRef)[NSRunLoop currentRunLoop];
}

void
CFRunLoopRun(void)
{
	[[NSRunLoop currentRunLoop] run];
}

SInt32
CFRunLoopRunInMode( CFStringRef mode,
					CFTimeInterval seconds,
					bool returnAfterSourceHandled)
{
	NSDate *date = [NSDate dateWithTimeIntervalSinceNow: seconds];
	NSRunLoop *rl = [NSRunLoop currentRunLoop];

	while (seconds > 0)						// Positive values are in future
		{
		id pool = [NSAutoreleasePool new];
		bool doMore = [rl runMode:(NSString *)mode beforeDate:date];

		[pool release];

		if (!doMore)
			return kCFRunLoopRunFinished;

		seconds = [date timeIntervalSinceNow];
		if (seconds > 0 && returnAfterSourceHandled)
			return kCFRunLoopRunHandledSource;
		}

	return kCFRunLoopRunTimedOut;			// FIX ME kCFRunLoopRunStopped
}

bool
CFRunLoopSourceIsValid (CFRunLoopSourceRef s)
{
	return ((RunLoopSource *)s)->_isValid;
}

CFRunLoopSourceRef
CFRunLoopSourceCreate(CFAllocatorRef a, CFIndex order, CFRunLoopSourceContext *cx)
{
	RunLoopSource *rs = (RunLoopSource*)NSAllocateObject([RunLoopSource class]);

	if (cx)
		memcpy(&rs->context, cx, sizeof(CFRunLoopSourceContext));

	return (CFRunLoopSourceRef)rs;
}

CFRunLoopSourceRef
CFSocketCreateRunLoopSource(CFAllocatorRef a, CFSocketRef s, CFIndex order)
{
	RunLoopSource *r = (RunLoopSource*)NSAllocateObject([RunLoopSource class]);

	r->socket = s;
//	r->limit = [NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)order];
	((CFSocket *)s)->runLoopSource = r;
	r->order = order;

	return (CFRunLoopSourceRef)r;
}

void
CFRunLoopSourceInvalidate (CFRunLoopSourceRef s)
{
//	if (((RunLoopSource *)s)->_isValid)		// outer src is never enabled FIX ME
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), s, kCFRunLoopCommonModes);
	((RunLoopSource *)s)->_isValid = NO;
}

void
CFRunLoopSourceSignal (CFRunLoopSourceRef s)
{
	CFOptionFlags f = _RunLoopSourceGetCallbackTypes((RunLoopSource*)s);

	if ((f & kCFSocketWriteCallBack) || (f & kCFSocketConnectCallBack))
		_RunLoopSourceWriteReady((RunLoopSource *)s, PTR2INT(((RunLoopSource *)s)->source));
	if ((f & kCFSocketReadCallBack) || (f & kCFSocketAcceptCallBack))
		_RunLoopSourceReadReady((RunLoopSource *)s, PTR2INT(((RunLoopSource *)s)->source));
}

CFIndex
CFRunLoopSourceGetOrder( CFRunLoopSourceRef s)
{
	return ((RunLoopSource *)s)->order;			// FIX ME order ignored
}

void
CFRunLoopSourceGetContext( CFRunLoopSourceRef s, CFRunLoopSourceContext *c)
{
	memcpy(c, &((RunLoopSource *)s)->context, sizeof(CFRunLoopSourceContext));
}

// FIX ME inefficient, copies Run Loop source instead of just adding it to RL
// problem is that callback types can get overwritten in RunLoopSourceInit() if
// original is reused

void
CFRunLoopAddSource (CFRunLoopRef crl, CFRunLoopSourceRef src, CFStringRef mode)
{
	CFSocket *s = (CFSocket *)((CFRunLoopSource *)src)->socket;
	CFSocketContext *cx = s->context;
	NSRunLoop *rl = (NSRunLoop *)crl;
	SEL sel = (SEL)s->callout;
	id watcher = (id)cx->info;
	NSString *sa[] = { (NSString *)mode, nil };
	NSString **modes;
	int j;

	[(RunLoopSource *)src retain];				// adding a copy but must abide
												// by ownership rules
	if (mode == kCFRunLoopCommonModes)
		modes = ((CFRunLoop*)rl)->_commonRunLoopModes;
	else
		modes = sa;

	for (j = 0; modes[j] != nil; j++)  			// loop mode or common modes
		{
		NSString *m = modes[j];
		void *sd = INT2PTR(s->sd);
		RunLoopSource *e = [rl _getSource:sd forMode:m];

		if (e && e->target == watcher)
			e->_isValid = YES;

		if (!e || e->target != watcher)
			{
			CFRunLoopSourceContext cx = {0, watcher, NULL, NULL};

			e = (RunLoopSource *)CFRunLoopSourceCreate(NULL, 0, &cx);
			RunLoopSourceInit(e, sel, s);
												// Add event to run
			[rl _addSource:e forMode:m];		// loop array for mode
			[e release];						// Now held in array.
		}	}
}

void
CFRunLoopAddCommonMode(CFRunLoopRef rl, CFStringRef mode)
{
	CFStringRef *cm = (CFStringRef *)((CFRunLoop*)rl)->_commonRunLoopModes;
	int i = 0;

	for (; cm[i] != NULL && cm[i] != mode && i < MAX_COMMON_RL_MODES; i++);
	if (i < MAX_COMMON_RL_MODES)
		cm[i] = mode;							// no dup elements
	else
		NSLog(@"WARNING:  RunLoop common modes overflow ");
}

bool
CFRunLoopContainsSource(CFRunLoopRef rl, CFRunLoopSourceRef src, CFStringRef mode)
{
	CFSocket *s = (CFSocket *)((CFRunLoopSource *)src)->socket;
	CFSocketContext *cx = s->context;
	id watcher = (id)cx->info;
	NSString *sa[] = { (NSString *)mode, nil };
	NSString **modes = sa;
	int j;

	if (mode == kCFRunLoopCommonModes)
		modes = (NSString **)((CFRunLoop*)rl)->_commonRunLoopModes;

	for (j = 0; modes[j] != nil; j++)			// loop mode or common modes
	  	{
		NSString *m = modes[j];
		void *sd = INT2PTR(s->sd);
		RunLoopSource *e = [(NSRunLoop*)rl _getSource:sd forMode:m];

		if (e && e->target == watcher)
			return YES;
		}

	return NO;
}

void
CFRunLoopRemoveSource(CFRunLoopRef rl, CFRunLoopSourceRef src, CFStringRef mode)
{
	CFSocket *s = (CFSocket *)((CFRunLoopSource *)src)->socket;
	CFSocketContext *cx = s->context;
	id watcher = (id)cx->info;
	NSString *sa[] = { (NSString *)mode, nil };
	NSString **modes = sa;
	int j;

	if (mode == kCFRunLoopCommonModes)
		modes = ((CFRunLoop*)rl)->_commonRunLoopModes;

	for (j = 0; modes[j] != nil; j++)			// loop mode or common modes
	  	{
		NSString *m = modes[j];
		void *sd = INT2PTR(s->sd);
		RunLoopSource *e = [(NSRunLoop*)rl _getSource:sd forMode:m];

		if (e && e->target == watcher)
			RunLoopSourceRelease(e);
		}
}

/* ****************************************************************************

		CFSocket -- RunLoop support

** ***************************************************************************/

void
CFSocketDisableCallBacks (CFSocketRef socket, CFOptionFlags callBackTypes)
{
	CFSocket *s = (CFSocket *)socket;
	CFSocketContext *cx = s->context;
	NSRunLoop *rl = (NSRunLoop *)CFRunLoopGetCurrent();
	id watcher = (id)cx->info;
	NSString **modes = ((CFRunLoop*)rl)->_commonRunLoopModes;
	int j;

//	NSLog(@"CFSocketDisableCallBacks ");
	if (((s->callBackTypes & callBackTypes) & 0xf) == 0)
		return;

	s->callBackTypes &= ~callBackTypes;

	for (j = 0; modes[j] != nil; j++)			// loop mode or common modes
	  	{
		NSString *m = modes[j];
		void *sd = INT2PTR(s->sd);
		RunLoopSource *e = [rl _getSource:sd forMode:m];

		if (e && e->target == watcher)
			CFSocketSetSocketFlags(e->socket, s->callBackTypes);
		}
}

void
CFSocketEnableCallBacks (CFSocketRef socket, CFOptionFlags callBackTypes)
{
	CFSocket *s = (CFSocket *)socket;
	CFSocketContext *cx = s->context;
	NSRunLoop *rl = (NSRunLoop *)CFRunLoopGetCurrent();
	id watcher = (id)cx->info;
	NSString **modes = ((CFRunLoop*)rl)->_commonRunLoopModes;
	int j;

	if (s->callBackTypes & callBackTypes)
		return;

	s->callBackTypes |= callBackTypes;

	for (j = 0; modes[j] != nil; j++)			// loop mode or common modes
	  	{
		NSString *m = modes[j];
		void *sd = INT2PTR(s->sd);
		RunLoopSource *e = [rl _getSource:sd forMode:m];

		if (e && e->target == watcher)
			CFSocketSetSocketFlags(e->socket, s->callBackTypes);
		}
}
