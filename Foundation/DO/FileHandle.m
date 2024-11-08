/*
   FileHandle.m

   File handle extensions used by NSPortNameServer

   Copyright (C) 1997-2016 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	1997
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	April 2005

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSFileHandle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSRunLoop.h>

#include <CoreFoundation/CFRunLoop.h>

#if	defined(__WIN32__) && !defined(__CYGWIN__)
	#include <Windows32/Sockets.h>
#else
	#include <time.h>
	#include <sys/time.h>
	#include <sys/param.h>
	#include <sys/socket.h>
	#include <netinet/in.h>
	#include <arpa/inet.h>
	#include <signal.h>
#endif /* __WIN32__ */

#include <sys/file.h>
#include <sys/stat.h>
#include <sys/fcntl.h>

#include <netdb.h>
#include <ctype.h>


#define	NETBUF_SIZE	 4096			// Maximum data in single I/O operation


// class variables
NSString *_FileHandleConnectCompletionNotification = @"FileHandleConnectCompletionNotification";
NSString *_FileHandleWriteCompletionNotification = @"FileHandleWriteCompletionNotification";

extern NSString *NotificationKey;



@interface NSFileHandle  (_NSFileHandle_Socket_Ext)
- (void) _setNonBlocking:(BOOL)flag;
@end

/* ****************************************************************************

	NSFileHandle Extensions

** ***************************************************************************/

@implementation NSFileHandle  (_NSFileHandle_Extensions)

- (void) _setDescription:(struct sockaddr_in *)sin
{
	_description = [[NSString stringWithFormat: @"Address: %s  Port: %d",
						(char*)inet_ntoa(sin->sin_addr),
						(int)NSSwapHostShortToBig(sin->sin_port)] retain];
}

- (id) initAsClientInBackgroundAtAddress:(NSString*) a
								 service:(NSString*) s
								 protocol:(NSString*) p
								 forModes:(NSArray*) modes
{
	int net;
	struct sockaddr_in sin;
	const char *proto = "tcp";
	struct servent *sp;

	if (s == nil)
		return _NSInitError(self, @"bad argument - service is nil");

	if (p)
		proto = [p cString];

	memset(&sin, '\0', sizeof(sin));
	sin.sin_family = AF_INET;

	if (a == nil || [a isEqualToString: @""])
		sin.sin_addr.s_addr = NSSwapBigIntToHost(INADDR_LOOPBACK);
	else if ((sin.sin_addr.s_addr = inet_addr([a cString])) == -1)
		return _NSInitError(self, @"inet_addr bad argument");

	if (s == nil)
		sin.sin_port = 0;
	else if ((sp = getservbyname([s cString], proto)) == 0)
		{
		const char *ptr = [s cString];
		int val = atoi(ptr);

		while (isdigit(*ptr))
			ptr++;

		if (*ptr == '\0' && val <= 0xffff)
			{
			unsigned short v = val;

			sin.sin_port = NSSwapHostShortToBig(v);
			}
		else
			return _NSInitError(self, @"bad address-service-protocol combo");
		}
	else
		sin.sin_port = sp->s_port;

	[self _setDescription: &sin];

	if ((net = socket(AF_INET, SOCK_STREAM, PF_UNSPEC)) < 0)
		return _NSInitError(self, @"unable to create socket - %s", strerror(errno));

	if ((self = [self initWithFileDescriptor: net closeOnDealloc: YES]))
		{
		NSMutableDictionary *info;
	
		[self _setNonBlocking: YES];

		if ((connect(net, (struct sockaddr*)&sin, sizeof(sin)) < 0) && errno != EINPROGRESS)
			return _NSInitError(self, @"unable to make connection to %s:%d - %s",
								inet_ntoa(sin.sin_addr),
								NSSwapHostShortToBig(sin.sin_port),
								strerror(errno));

		info = [[NSMutableDictionary dictionaryWithCapacity: 4] retain];
		[info setObject:_description forKey:NSFileHandleNotificationDataItem];
		[info setObject: _FileHandleConnectCompletionNotification
			  forKey: NotificationKey];
		_fh.awaitConnect = YES;
		if (modes)
			[info setObject:modes forKey:NSFileHandleNotificationMonitorModes];
		_writeInfo = [[NSMutableArray array] retain];
		[_writeInfo addObject: info];
		[info release];
		[self watchWriteDescriptor];
		_fh.connectOK = YES;
		_fh.readOK = NO;
		_fh.writeOK = NO;
		}

	return self;
}

+ (NSFileHandle *) fileHandleAsClientInBackgroundAtAddress:(NSString*)aAddress
												   service:(NSString*)aService
												  protocol:(NSString*)aProtocol
												  forModes:(NSArray*)modes
{
    return [[[self alloc] initAsClientInBackgroundAtAddress:aAddress
						  service:aService
						  protocol:aProtocol
						  forModes:modes] autorelease];
}

- (void) writeInBackgroundAndNotify:(NSData*)item 
						   forModes:(NSArray*)modes
{
	NSMutableDictionary *info;

	[self _checkWrite];
	
	info = [[NSMutableDictionary dictionaryWithCapacity: 4] retain];
	[info setObject: item forKey: NSFileHandleNotificationDataItem];
	[info setObject: _FileHandleWriteCompletionNotification
		  forKey: NotificationKey];
	if (modes)
		[info setObject: modes forKey: NSFileHandleNotificationMonitorModes];
	
	[_writeInfo addObject: info];
	[info release];
	[self watchWriteDescriptor];
}

- (void) _checkWrite
{
	if (_fh.writeOK == NO)
		[NSException raise: NSFileHandleOperationException
					 format: @"write not permitted in this file handle"];

	if ([_writeInfo count] > 0)
		{
		id info = [_writeInfo objectAtIndex: 0];
		id operation = [info objectForKey: NotificationKey];

		if (operation == _FileHandleConnectCompletionNotification)
			[NSException raise: NSFileHandleOperationException
						 format: @"connect already in progress"];
		}
}

- (void) postReadNotification
{
	NSMutableDictionary *info = _note;
	NSNotification *n;
	NSArray *modes;
	NSString *name;

	[self ignoreReadDescriptor];
	_note = nil;
	modes = (NSArray*)[info objectForKey:NSFileHandleNotificationMonitorModes];
	name = (NSString*)[info objectForKey:NotificationKey];
	
	n = [NSNotification notificationWithName: name object: self userInfo:info];
	
	[info release];							// Retained by the notification.	

	[[NSNotificationQueue defaultQueue] enqueueNotification: n
										postingStyle: NSPostASAP
										coalesceMask:NSNotificationNoCoalescing
										forModes: modes];
}

- (void) postWriteNotification
{
	NSMutableDictionary *info = [_writeInfo objectAtIndex: 0];
	NSNotification *n;
	NSArray *modes;
	NSString *name;

	[self ignoreWriteDescriptor];
	modes = (NSArray*)[info objectForKey:NSFileHandleNotificationMonitorModes];
	name = (NSString*)[info objectForKey: NotificationKey];

	n = [NSNotification notificationWithName:name object:self userInfo:info];

	_writePos = 0;
	[_writeInfo removeObjectAtIndex: 0];		// Retained by notification

	[[NSNotificationQueue defaultQueue] enqueueNotification: n
										postingStyle: NSPostASAP
										coalesceMask: NSNotificationNoCoalescing
										forModes: modes];
	if ((_fh.writeOK || _fh.connectOK) && [_writeInfo count] > 0)
		[self watchWriteDescriptor];			// In case of queued writes.
}

- (void) ignoreReadDescriptor
{
	if (_descriptor >= 0 && _cfSocket)
		{
		CFRunLoopRef rl = CFRunLoopGetCurrent();
		NSArray *modes = nil;
		int i, count;
		CFRunLoopSourceRef rs = ((CFSocket *)_cfSocket)->runLoopSource;

		if (_note)
			modes = (NSArray*)[_note objectForKey: NSFileHandleNotificationMonitorModes];

		if (modes && (count = [modes count]))
			for (i = 0; i < count; i++)
				CFRunLoopRemoveSource(rl, rs, (CFStringRef)[modes objectAtIndex: i]);
		else
			CFRunLoopRemoveSource(rl, rs, (CFStringRef)NSDefaultRunLoopMode);
		}
}

// FIX ME disable seems more appropriate, but requires further work in RunLoop
// CFSocketDisableCallBacks (CFSocketRef socket, CFOptionFlags callBackTypes)

- (void) ignoreWriteDescriptor
{
	if (_descriptor >= 0 && _cfSocket)
		{
		CFRunLoopRef rl = CFRunLoopGetCurrent();
		NSArray *modes = nil;
		int i, count;
		CFRunLoopSourceRef rs = ((CFSocket *)_cfSocket)->runLoopSource;

		if ([_writeInfo count] > 0)
			{
			NSMutableDictionary *info = [_writeInfo objectAtIndex: 0];
	
			modes = (NSArray*)[info objectForKey: 
					NSFileHandleNotificationMonitorModes];
			}
	
		if (modes && (count = [modes count]))
			for (i = 0; i < count; i++)
				CFRunLoopRemoveSource(rl, rs, (CFStringRef)[modes objectAtIndex: i]);
		else
			CFRunLoopRemoveSource(rl, rs, (CFStringRef)NSDefaultRunLoopMode);
		}
}

- (void) watchWriteDescriptor
{
	if ((_descriptor >= 0) && [_writeInfo count] > 0)
		{
		NSMutableDictionary *info = [_writeInfo objectAtIndex: 0];
		CFRunLoopRef rl = CFRunLoopGetCurrent();
		CFOptionFlags fl = kCFSocketWriteCallBack;
		CFSocketContext cx = { 0, self, NULL, NULL, NULL };
		SEL scb = @selector(_writeDescriptorReady:);
		CFSocketCallBack cb = (CFSocketCallBack)scb;
		CFRunLoopSourceRef rs;
		NSArray *modes;
		int i, count;

		_cfSocket = CFSocketCreateWithNative(NULL, _descriptor, fl, cb, &cx);
		modes = [info objectForKey: NSFileHandleNotificationMonitorModes];

		[self _setNonBlocking: YES];

		if ((rs = CFSocketCreateRunLoopSource(NULL, _cfSocket, 0)) == NULL)
			[NSException raise:NSGenericException format:@"CFSocket init error"];
		if (modes && (count = [modes count]))
			{
			for (i = 0; i < count; i++)
				{
				CFStringRef m = (CFStringRef)[modes objectAtIndex: i];

				CFRunLoopAddSource(rl, rs, m);
			}	}
		else
			CFRunLoopAddSource(rl, rs, (CFStringRef)NSDefaultRunLoopMode);
		CFRelease(rs);
		}
}

- (void) _readDescriptorReady:(id)sender
{
	NSString *operation;

	if (_fh.isNonBlocking == NO)
		[self _setNonBlocking: YES];

	operation = [_note objectForKey: NotificationKey];

	if (operation == NSFileHandleConnectionAcceptedNotification)
		{
		struct sockaddr_in buf;
		unsigned blen = sizeof(buf);
		int sd = accept(_descriptor, (struct sockaddr*)&buf, &blen);

		if (sd < 0)
			[_note setObject: [NSNumber numberWithInt:errno]
				   forKey: NSFileHandleError];
		else
			{								// Accept attempt completed.
			id h = [[NSFileHandle alloc] initWithFileDescriptor: sd];
			struct sockaddr_in sin;
			unsigned size = sizeof(sin);
	
			if (getpeername(sd, (struct sockaddr*)&sin, &size) == -1)
				NSLog(@"Error getting peer name %s", strerror(errno));
			else
				[h _setDescription: &sin];
			[_note setObject: h 
				   forKey: NSFileHandleNotificationFileHandleItem];
			[h release];
			}
		[self postReadNotification];
		}
	else
		{
		if (operation == NSFileHandleDataAvailableNotification)
			[self postReadNotification];
		else
			{
			NSMutableData *t;
			int length, received = 0;
			char buf[NETBUF_SIZE];
		
			t = [_note objectForKey: NSFileHandleNotificationDataItem];
			length = [t length];
		
			received = read(_descriptor, buf, sizeof(buf));
			if (received == 0)					// Read up to end of file.
				[self postReadNotification];
			else 
				if (received < 0)
					{
					if (errno != EAGAIN)
						{
						[_note setObject: [NSNumber numberWithInt:errno]
							   forKey: NSFileHandleError];
						[self postReadNotification];
					}	}
				else
					{
					[t appendBytes: buf length: received];
					if(operation == NSFileHandleReadCompletionNotification)
						[self postReadNotification];	// Read a single 
		}	}		}									// chunk of data
}

- (void) _writeDescriptorReady:(id)sender
{
	if (_fh.isNonBlocking == NO)
		[self _setNonBlocking: YES];

///	if (operation == _FileHandleWriteCompletionNotification)
	if (_fh.awaitConnect)
		{								// Connection attempt completed
		int	result;
		unsigned len = sizeof(result);
	
		if (getsockopt(_descriptor, SOL_SOCKET, SO_ERROR, (char*)&result, &len) == 0
				&& result != 0)
			{
			NSMutableDictionary	*info = [_writeInfo objectAtIndex: 0];
			NSString *operation = [info objectForKey: NotificationKey];

			[info setObject: [NSNumber numberWithInt:result]
				  forKey: NSFileHandleError];
			}
		else
			_fh.readOK = _fh.writeOK = YES;

		_fh.connectOK = _fh.awaitConnect = NO;
		[self postWriteNotification];
		}
	else
		{
		NSMutableDictionary	*info = [_writeInfo objectAtIndex: 0];
		NSString *operation = [info objectForKey: NotificationKey];
		NSData *i = [info objectForKey:NSFileHandleNotificationDataItem];
		NSUInteger length = [i length];
		const void *ptr = [i bytes];

		if (_writePos < length)
			{
			int	written = write(_descriptor, (char*)ptr + _writePos, length - _writePos);

			if (written <= 0)
				{
				if (errno != EAGAIN)
					{
					[_note setObject: [NSNumber numberWithInt:errno]
						   forKey: NSFileHandleError];
					[self postWriteNotification];
				}	}
			else
				_writePos += written;
			}
		if (_writePos >= length)			// Write operation completed.
			[self postWriteNotification];
		}
}

@end  /* NSFileHandle  (_NSFileHandle_Extensions) */
