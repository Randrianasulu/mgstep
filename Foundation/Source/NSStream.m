/*
   NSStream.m

   Opaque data source or destination stream

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    May 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSStream.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFStream.h>


@implementation NSStream

+ (id) alloc										{ return nil; }

- (id) init
{
	return (_delegate = (id <NSStreamDelegate>)self);
}

- (void) open
{
	if (_streamStatus != NSStreamStatusNotOpen)
		_streamStatus = NSStreamStatusError;
	else
		{
		_streamStatus = NSStreamStatusOpening;
		if (_sm.sendEvents)
			[_delegate stream:self handleEvent:NSStreamEventOpenCompleted];

		_streamStatus = (_streamStatus == NSStreamStatusOpening)
						? NSStreamStatusOpen : NSStreamStatusError;
		}
}

- (void) close
{
	_streamStatus = (_streamStatus > 0 && _streamStatus < NSStreamStatusClosed)
					? NSStreamStatusClosed : NSStreamStatusError;

	if (_streamStatus == NSStreamStatusClosed)
		{
		NSRunLoop *rl = [NSRunLoop currentRunLoop];

		[self removeFromRunLoop:rl forMode:(id)kCFRunLoopCommonModes];
		}
}

- (void) scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSString *)m  { SUBCLASS; }
- (void) removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)m  { SUBCLASS; }

- (id <NSStreamDelegate>) delegate					{ return _delegate; }

- (void) setDelegate:(id <NSStreamDelegate>)d
{
	_delegate = d = (d == nil) ? (id <NSStreamDelegate>)self : d;
	_sm.sendEvents = [d respondsToSelector:@selector(stream:handleEvent:)];
}

- (id) propertyForKey:(NSString *)key				{ return nil; }
- (BOOL) setProperty:(id)val forKey:(NSString *)key	{ return NO; }

- (NSStreamStatus) streamStatus						{ return _streamStatus; }
- (NSError *) streamError 							{ return _streamError; }

@end


@implementation NSInputStream

+ (id) alloc			  					{ return NSAllocateObject(self); }

- (void) _readDescriptorReady:(id)sender
{
//	NSLog(@"NSStream _readDescriptorReady");
	if (_sm.sendEvents)
		do {
		  [_delegate stream:self handleEvent:NSStreamEventHasBytesAvailable];
		} while (_streamStatus == NSStreamStatusReading);
}

- (void) scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSString *)m
{
	CFOptionFlags of = kCFSocketReadCallBack;
	CFSocketContext cx = { 0, self, NULL, NULL, NULL };
	SEL scb = @selector(_readDescriptorReady:);
	CFSocketCallBack cb = (CFSocketCallBack)scb;
	CFSocketRef s = CFSocketCreateWithNative(NULL, _fd, of, cb, &cx);
    CFRunLoopSourceRef rs = CFSocketCreateRunLoopSource(NULL, s, 0);

    CFRunLoopAddSource((CFRunLoopRef)rl, rs, (CFStringRef)m);
    CFRelease(rs);
	_socket = s;
}

- (void) removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)m
{
//	CFRunLoopRemoveSource(CFRunLoopRef rl, CFRunLoopSourceRef src, CFStringRef mode)
	if (_socket)
		{
//		if (!_sm.closesNativeSocket)
//			close();					// ~kCFSocketCloseOnInvalidate
		CFSocketInvalidate ((CFSocketRef)_socket);
		CFRelease((CFSocketRef)_socket), _socket = NULL;
		}
}

- (BOOL) hasBytesAvailable										{ return YES; }
- (BOOL) getBuffer:(uint8_t **)b length:(NSUInteger *)l			{ return NO; }

- (NSInteger) read:(uint8_t *)buf maxLength:(NSUInteger)ml
{
	NSInteger nread;

	_streamStatus = NSStreamStatusReading;

	if ((nread = (NSInteger) read(_fd, buf, ml)) <= 0)
		{
		if (nread == 0 || errno == EAGAIN || errno == EWOULDBLOCK)
			_streamStatus = NSStreamStatusAtEnd;
		else
			{
			_streamStatus = NSStreamStatusError;
			NSLog(@"NSInputStream read error (%d) %s", errno, strerror(errno));
		}	}

	return nread;
}

@end


@implementation NSOutputStream

+ (id) alloc			  					{ return NSAllocateObject(self); }

- (void) _writeDescriptorReady:(id)sender
{
//	NSLog(@"NSStream _writeDescriptorReady");
	if (_sm.sendEvents)
		[_delegate stream:self handleEvent:NSStreamEventHasSpaceAvailable];
	_streamStatus = NSStreamStatusOpen;
}

- (void) scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSString *)m
{
	CFOptionFlags of = kCFSocketWriteCallBack;
	CFSocketContext cx = { 0, self, NULL, NULL, NULL };
	SEL scb = @selector(_writeDescriptorReady:);
	CFSocketCallBack cb = (CFSocketCallBack)scb;
	CFSocketRef s = CFSocketCreateWithNative(NULL, _fd, of, cb, &cx);
    CFRunLoopSourceRef rs = CFSocketCreateRunLoopSource(NULL, s, 0);

    CFRunLoopAddSource((CFRunLoopRef)rl, rs, (CFStringRef)m);
    CFRelease(rs);
	_socket = s;
}

- (void) removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)m
{
//	CFRunLoopRemoveSource(CFRunLoopRef rl, CFRunLoopSourceRef src, CFStringRef mode)
	if (_socket)
		{
//		if (!_sm.closesNativeSocket)
//			close();					// ~kCFSocketCloseOnInvalidate
		CFSocketInvalidate ((CFSocketRef)_socket);
		CFRelease((CFSocketRef)_socket), _socket = NULL;
		}
}

- (BOOL) hasSpaceAvailable										{ return YES; }

- (NSInteger) write:(const uint8_t *)buf maxLength:(NSUInteger)ml
{
	_streamStatus = NSStreamStatusWriting;

	return (NSInteger) write(_fd, buf, ml);
}

- (BOOL) setProperty:(id)v forKey:(NSString *)key
{
	return CFWriteStreamSetProperty((CFWriteStreamRef)self, (CFStringRef)key, v);
}

@end

/* ****************************************************************************

		CFStream

** ***************************************************************************/

typedef struct _NSStream  { @defs(NSStream); } CFStream;

CFStringRef kCFStreamPropertyShouldCloseNativeSocket =
			(CFStringRef)@"kCFStreamPropertyShouldCloseNativeSocket";

void
CFStreamCreatePairWithSocket( CFAllocatorRef a,
							  CFSocketNativeHandle socketHandle,
							  CFReadStreamRef *readStream,
							  CFWriteStreamRef *writeStream)
{
	if (socketHandle < 0)
		return;
	if (readStream)
		{
		*readStream = (CFReadStreamRef)[NSInputStream new];
		((CFStream *) *readStream)->_fd = socketHandle;
		}
	if (writeStream)
		{
		*writeStream = (CFWriteStreamRef)[NSOutputStream new];
		((CFStream *) *writeStream)->_fd = socketHandle;
		}
}

bool
CFReadStreamSetProperty( CFReadStreamRef s, CFStringRef key, CFTypeRef value)
{
	if (key == kCFStreamPropertyShouldCloseNativeSocket && value)
		{
		((CFStream *)s)->_sm.closesNativeSocket = *(int *)value;
		
		return YES;
		}

	return NO;
}

bool
CFWriteStreamSetProperty(CFWriteStreamRef s, CFStringRef key, CFTypeRef value)
{
	return CFReadStreamSetProperty(s, key, value);
}
