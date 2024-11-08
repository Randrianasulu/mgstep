/*
   CFBase.m

   mini Core Foundation implementation

   Copyright (C) 2009-2016 Free Software Foundation, Inc.

   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Sep 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFRuntime.h>
#include <CoreFoundation/CFRunLoop.h>

#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <fcntl.h>


const CFTimeInterval kCFAbsoluteTimeIntervalSince1970 = 978307200.0L;

const CFAllocatorRef kCFAllocatorDefault = NULL;
const CFAllocatorRef kCFAllocatorNull = NULL;



typedef struct {
	CFRuntimeClass * cf_pointer;
} _CFType;


CFTypeRef
CFRetain(CFTypeRef cf)
{
	if (cf)
		NSIncrementExtraRefCount((id) cf);

	return cf;
}

void
CFRelease(CFTypeRef cf)
{
	if (NSDecrementExtraRefCountWasZero((id) cf))
		[(id)cf dealloc];
}

CFIndex
CFGetRetainCount(CFTypeRef cf)
{
	return NSExtraRefCount((id) cf);
}

CFTypeID
CFGetTypeID(CFTypeRef cf)
{
	return (CFTypeID)((_CFType*)cf)->cf_pointer;
}

void
CFShow (CFTypeRef cf)
{
  if (((_CFType*)cf)->cf_pointer->version == _CF_VERSION)
	  NSLog(@"CF type %s, version %d",((_CFType*)cf)->cf_pointer->className,
									  ((_CFType*)cf)->cf_pointer->version);
  else
	  NSLog(@"Not a CF type");
}

CFAbsoluteTime
CFAbsoluteTimeGetCurrent(void)
{
    CFAbsoluteTime at;
    struct timeval tv;

    gettimeofday(&tv, NULL);
    at = (CFTimeInterval)tv.tv_sec - kCFAbsoluteTimeIntervalSince1970;
    at += (1.0E-6 * (CFTimeInterval)tv.tv_usec);

    return at;
}

/* ****************************************************************************

		CFSocket

** ***************************************************************************/

static const CFRuntimeClass __CFSocketClass = {
	_CF_VERSION,
	"CFSocket",
	NULL
};


CFTypeID CFSocketGetTypeID(void)		{ return (CFTypeID)&__CFSocketClass; }

CFSocketRef
CFSocketCreateWithNative(CFAllocatorRef a,
						 CFSocketNativeHandle sock,
						 CFOptionFlags callBackTypes,
						 CFSocketCallBack callout,
						 const CFSocketContext *context)
{
	unsigned int size = sizeof(CFSocket) + sizeof(CFSocketContext);
	CFSocket *s = CFAllocatorAllocate(a, size, 0);

	s->cf_pointer = (void *)&__CFSocketClass;
	s->sd = sock;
	s->flags = kCFSocketCloseOnInvalidate;
	if (callBackTypes && callBackTypes <= kCFSocketDataCallBack)
		s->flags |= callBackTypes;					// add default reenable
	s->callBackTypes = callBackTypes;
	s->callout = callout;
	s->context = (void *)s + sizeof(CFSocket);
	memcpy(s->context, context, sizeof(CFSocketContext));

	return (CFSocketRef)s;
}

CFSocketRef
CFSocketCreate (CFAllocatorRef a,
				SInt32 domain,
				SInt32 socketType,
				SInt32 protocol,
				CFOptionFlags callBackTypes,
				CFSocketCallBack callout,
				const CFSocketContext *cx)
{
	CFSocket *s;

	s = (CFSocket *)CFSocketCreateWithNative(a, 0, callBackTypes, callout, cx);

	if (domain <= 0)
		domain = PF_INET;
	if (domain == PF_INET && socketType <= 0)
		socketType = SOCK_STREAM;
	if (domain == PF_INET && protocol <= 0)
		protocol = (socketType == SOCK_STREAM) ? IPPROTO_TCP : IPPROTO_UDP;

	if ((s->sd = socket(domain, socketType, protocol)) == -1)
		NSLog(@"CFSocketCreate: error creating socket %s\n", strerror(errno));

	s->sig.protocolFamily = domain;
	s->sig.socketType	  = socketType;
	s->sig.protocol		  = protocol;

	return (CFSocketRef)s;
}

int
_CFSocketSetNonBlocking(CFSocket *s)
{
	int r;

	if ((r = fcntl(s->sd, F_GETFL, 0)) < 0)
		NSLog(@"CF: Unable to get socket non-blocking status\n");
	else if ((r = fcntl(s->sd, F_SETFL, (r | O_NONBLOCK))) < 0)
		NSLog(@"CF: Unable to set socket non-blocking\n");

	return r;
}

CFSocketError
CFSocketConnectToAddress (CFSocketRef socket,
						  CFDataRef address,
						  CFTimeInterval timeout)
{
	CFSocket *s = (CFSocket *)socket;
	struct {  struct sockaddr_in  sa;
			  struct sockaddr_in6 sa6; } u;
	int addrlen = sizeof(u.sa);
	int r;

	if ([(NSData *)address length] == addrlen)				// IPv4
		[(NSData *)address getBytes:&u.sa length:addrlen];
	else
		{													// IPv6
		addrlen = sizeof(u.sa6);
		[(NSData *)address getBytes:&u.sa6 length:addrlen];
		}

	if (timeout < 0)										// non-blocking I/O
		_CFSocketSetNonBlocking(s);
	else													// blocking I/O
		{
		struct timeval tv;

		tv.tv_sec = timeout;
		if (setsockopt(s->sd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0)
			NSLog(@"CF: Unable to set socket timeout\n");
		}

	if ((r = connect(s->sd, (struct sockaddr *)&u, addrlen)) != 0)
		if (errno != EINPROGRESS || !s->sd)
			{
			if (errno == EALREADY && s->sd)
				NSLog(@"CF: Existing connect attempt on non-blocking socket");
			else
				NSLog(@"CF: Error connecting to socket (%d) %s\n", s->sd, strerror(errno));

			return kCFSocketError;
			}

	if (r != 0)
		NSLog(@"CF: CFSocketConnectToAddress awaiting connect");

	return kCFSocketSuccess;
}

bool
_CFSocketCanAccept(CFSocketRef s)
{
	return ((((CFSocket *)s)->callBackTypes & kCFSocketAcceptCallBack)
			&& ( ((CFSocket *)s)->sig.socketType == SOCK_STREAM
			  || ((CFSocket *)s)->sig.socketType == SOCK_SEQPACKET ));
}

CFSocketError
CFSocketSetAddress(CFSocketRef s, CFDataRef address)
{
    CFSocketNativeHandle sd = CFSocketGetNative(s);
    struct sockaddr_storage sa;
    socklen_t len;
	int e;

    if (!address || (len = [(NSData *)address length]) < sizeof(struct sockaddr))
		return kCFSocketError;

	[(NSData *)address getBytes:&sa length:len];

    if ((e = bind(sd, (struct sockaddr *)&sa, len)) != 0)
		NSLog(@"CFSocketSetAddress bind error: (%d) %s", errno, strerror(errno));
	else if ( _CFSocketCanAccept(s) && (e = listen(sd, 256)) != 0 )
		NSLog(@"CFSocketSetAddress listen error: (%d) %s", errno, strerror(errno));

	return e == 0 ? kCFSocketSuccess : kCFSocketError;
}

CFDataRef
CFSocketCopyAddress(CFSocketRef s)
{
    CFDataRef d = (CFDataRef)CFRetain(((CFSocket *)s)->sig.address);

    return d;
}

bool
CFSocketIsValid(CFSocketRef s)
{
	return (((CFSocket *)s)->sd != -1);
//	S_ISSOCK(m)
}

void
CFSocketSetSocketFlags(CFSocketRef s, CFOptionFlags flags)
{
	((CFSocket *)s)->flags = flags;
}

CFOptionFlags
CFSocketGetSocketFlags(CFSocketRef s)
{
	return ((CFSocket *)s)->flags;
}

CFSocketNativeHandle
CFSocketGetNative(CFSocketRef s)
{
	return ((CFSocket *)s)->sd;
}

/* ****************************************************************************

	CFSocketInvalidate

	Apple website notes:
	
	- does not (directly) release object itself
	- invalidates any assoicated Run Loop source
	- calls context release callback for info field release (if any)
	- closes the underlying socket unless flag kCFSocketCloseOnInvalidate
	  has been cleared by calling CFSocketSetSocketFlags()

** ***************************************************************************/

void
CFSocketInvalidate (CFSocketRef socket)
{
	CFSocket *s = (CFSocket *)socket;

	if (s->runLoopSource)
		{
		CFRunLoopSourceRef rs = (CFRunLoopSourceRef)s->runLoopSource;

		s->runLoopSource = NULL;	// FIX ME released here or by creator ???
		CFRunLoopSourceInvalidate(rs);
		}
	
	if (s->context && s->context->release && s->context->info)
		{
		CFSocketContext cx;
		
		cx.release = s->context->release;
		cx.info = s->context->info;
	 	s->context->release = s->context->info = NULL;
		cx.release(cx.info);
		}

	if (s->flags & kCFSocketCloseOnInvalidate)
		{				// don't close if kCFSocketCloseOnInvalidate is clear
		if (s->sd >= 0)
			close(s->sd);
		else
			NSLog(@"CFSocketInvalidate attempt to invalidate non-socket");
		s->sd = -1;
		}
}

/* ****************************************************************************

		CFArray

** ***************************************************************************/

CFArrayRef
CFArrayCreate(CFAllocatorRef a, const void **values, CFIndex n, const void *cb)
{
	return (CFArrayRef)[[NSArray alloc] initWithObjects:(id *)values count:n];
}

/* ****************************************************************************

		Bridge ObjC <--> C

** ***************************************************************************/

@interface _CFBridge : NSObject
{
	_CFType *cf_pointer;
}

@end

@implementation _CFBridge

- (void) dealloc
{
	if (cf_pointer && ((CFRuntimeClass *)cf_pointer)->dealloc)
		((CFRuntimeClass *)cf_pointer)->dealloc((_CFType *)self);

	CFAllocatorDeallocate (NULL, (_CFType *)self);
	NO_WARN;
}

@end

void __initBridgeClass(void)	{ _CFBridgeInit([_CFBridge class]); }
