/*
   CFRunLoop.h

   mini Core Foundation run-loop

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	September 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_CFRunLoop
#define _mGSTEP_H_CFRunLoop

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFSocket.h>


typedef const struct _NSRunLoop       * CFRunLoopRef;
typedef const struct _CFRunLoopSource * CFRunLoopSourceRef;

// typedef struct _CFRunLoopTimer    * CFRunLoopTimerRef;
// typedef struct _CFRunLoopObserver * CFRunLoopObserverRef;

/* ****************************************************************************

	Common RunLoop modes typically contains several modes including the
	default kCFRunLoopDefaultMode.  Each RunLoop has its own independent
	set of common modes.  To add a mode use CFRunLoopAddCommonMode().

** ***************************************************************************/

extern const CFStringRef kCFRunLoopCommonModes;		// NSRunLoopCommonModes
extern const CFStringRef kCFRunLoopDefaultMode;		// NSDefaultRunLoopMode

enum {								// CFRunLoopRunInMode() return codes
    kCFRunLoopRunFinished      = 1,
    kCFRunLoopRunStopped       = 2,
    kCFRunLoopRunTimedOut      = 3,
    kCFRunLoopRunHandledSource = 4
};

extern void CFRunLoopRun(void);

extern void CFRunLoopStop( CFRunLoopRef rl);

extern SInt32 CFRunLoopRunInMode( CFStringRef mode,
								  CFTimeInterval seconds,
								  bool returnAfterSourceHandled);


typedef struct {									// ** not same as Apple CF
    CFIndex	    version;
    void        *info;
    CFStringRef	(*copyDescription)(const void *info);	// describe info obj
    void	    (*perform)(void *info);					// callback when fired
} CFRunLoopSourceContext;


extern CFRunLoopRef CFRunLoopGetCurrent(void);
									// Add RunLoop mode to set of common modes
extern void CFRunLoopAddCommonMode( CFRunLoopRef rl, CFStringRef mode);

extern CFRunLoopSourceRef CFRunLoopSourceCreate( CFAllocatorRef a,
												 CFIndex order,
												 CFRunLoopSourceContext *c);

extern CFRunLoopSourceRef CFSocketCreateRunLoopSource( CFAllocatorRef a,
													   CFSocketRef s,
													   CFIndex order);

extern bool CFRunLoopSourceIsValid( CFRunLoopSourceRef s);
extern bool CFRunLoopContainsSource(CFRunLoopRef rl, CFRunLoopSourceRef s, CFStringRef mode);

extern void CFRunLoopAddSource( CFRunLoopRef rl, CFRunLoopSourceRef s, CFStringRef mode);
extern void CFRunLoopRemoveSource( CFRunLoopRef rl, CFRunLoopSourceRef s, CFStringRef mode);

extern void CFRunLoopSourceInvalidate( CFRunLoopSourceRef s);
extern void CFRunLoopSourceSignal( CFRunLoopSourceRef s);

extern CFIndex CFRunLoopSourceGetOrder( CFRunLoopSourceRef s);
extern void  CFRunLoopSourceGetContext( CFRunLoopSourceRef s,
										CFRunLoopSourceContext *c);

#endif  /* _mGSTEP_H_CFRunLoop */
