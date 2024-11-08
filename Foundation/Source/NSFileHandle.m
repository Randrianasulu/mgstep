/*
   NSFileHandle.m

   Wrap low level file and socket access.

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    April 2005

   Rewrite from earlier code now used only for Distributed Objects.

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
#include <CoreFoundation/CFSocket.h>

#include <sys/file.h>
#include <sys/stat.h>
#include <fcntl.h>


#define	MAX_IO_SIZE	 4096


// class variables
static NSFileHandle *__stdin = nil;
static NSFileHandle *__stdout = nil;
static NSFileHandle *__stderr = nil;

							// Key to info dictionary for operation mode.
NSString *NotificationKey = @"NSFileHandleNotificationKey";

													// Note handler access keys
NSString *NSFileHandleNotificationDataItem = @"NSFileHandleNotificationDataItem";
NSString *NSFileHandleNotificationFileHandleItem = @"NSFileHandleNotificationFileHandleItem";
NSString *NSFileHandleNotificationMonitorModes = @"NSFileHandleNotificationMonitorModes";
NSString *NSFileHandleError = @"NSFileHandleError";
													// Notification names
NSString *NSFileHandleConnectionAcceptedNotification = @"NSFileHandleConnectionAcceptedNotification";
NSString *NSFileHandleDataAvailableNotification = @"NSFileHandleDataAvailableNotification";
NSString *NSFileHandleReadCompletionNotification = @"NSFileHandleReadCompletionNotification";
NSString *NSFileHandleReadToEndOfFileCompletionNotification = @"NSFileHandleReadToEndOfFileCompletionNotification";

													// Exceptions
NSString *NSFileHandleOperationException = @"NSFileHandleOperationException";



@implementation NSFileHandle

+ (NSFileHandle *) fileHandleForReadingAtPath:(NSString*)path
{
	NSFileHandle *f;
	int fd = open([path fileSystemRepresentation], O_RDONLY);

	if (fd < 0)
		return nil;

	if ((f = [[self alloc] initWithFileDescriptor:fd closeOnDealloc:YES]))
		f->_fh.writeOK = NO;

    return [f autorelease];
}

+ (NSFileHandle *) fileHandleForWritingAtPath:(NSString*)path
{
	NSFileHandle *f;
	int fd;

	if ((fd = open([path fileSystemRepresentation], O_WRONLY)) < 0)
		return nil;

	if ((f = [[self alloc] initWithFileDescriptor: fd closeOnDealloc: YES]))
		f->_fh.readOK = NO;

    return [f autorelease];
}

+ (NSFileHandle *) fileHandleForUpdatingAtPath:(NSString*)path
{
	int fd = open([path fileSystemRepresentation], O_RDWR);

    return (fd < 0) ? nil : [[[self alloc] initWithFileDescriptor:fd 
										   closeOnDealloc:YES] autorelease];
}

+ (NSFileHandle *) fileHandleWithStandardInput
{
	if (!__stdin)
		{
		__stdin = [[self alloc] initWithFileDescriptor:0 closeOnDealloc:YES];
		__stdin->_fh.writeOK = NO;
		}

    return __stdin;
}

+ (NSFileHandle *) fileHandleWithStandardOutput
{
	if (!__stdout)
		{
		__stdout = [[self alloc] initWithFileDescriptor:1 closeOnDealloc:YES];
		__stdout->_fh.readOK = NO;
		}

    return __stdout;
}

+ (NSFileHandle *) fileHandleWithStandardError
{
	if (!__stderr)
		{
		__stderr = [[self alloc] initWithFileDescriptor:2 closeOnDealloc:YES];
		__stderr->_fh.readOK = NO;
		}

    return __stderr;
}

+ (NSFileHandle *) fileHandleWithNullDevice
{
    return [[[self alloc] init] autorelease];
}

- (id) init
{
	int fd = open("/dev/null", O_RDWR);

	return [self initWithFileDescriptor: fd closeOnDealloc:YES];
}

- (NSFileHandle *) initWithFileDescriptor:(int)desc
{
    return [self initWithFileDescriptor:desc closeOnDealloc:NO];
}

- (NSFileHandle *) initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)flag
{
	if ((self = [super init]))
		{
		struct stat sbuf;
		int e;

		if (fstat(fd, &sbuf) < 0)
			return _NSInitError(self, @"unable to stat fd %s", strerror(errno));

		_fh.isRegularFile = (S_ISREG(sbuf.st_mode)) ? YES : NO;

		if ((e = fcntl(fd, F_GETFL, 0)) >= 0)
			_fh.wasNonBlocking = (e & O_NONBLOCK) ? YES : NO;

		_descriptor = fd;
		_fh.readOK = YES;
		_fh.writeOK = YES;
		_fh.closeOnDealloc = flag;
		_fh.isNonBlocking = _fh.wasNonBlocking;
		}

	return self;
}

- (void) _setNonBlocking:(BOOL)flag
{
	int e;

	if ((_descriptor < 0) || (_fh.isRegularFile) || (_fh.isNonBlocking == flag))
		return;

	if ((e = fcntl(_descriptor, F_GETFL, 0)) >= 0)
		{
		e = (flag) ? (e | O_NONBLOCK) : (e & ~O_NONBLOCK);

		if (fcntl(_descriptor, F_SETFL, e) < 0)
			NSLog(@"unable to set non-blocking mode - %s", strerror(errno));
		else
			_fh.isNonBlocking = flag;
		}
	else
		NSLog(@"unable to get non-blocking mode - %s", strerror(errno));
}

- (void) dealloc
{
	if ((_fh.closeOnDealloc == YES) && (_descriptor != -1))
		[self closeFile];
	else if (_descriptor != -1 && (_fh.isNonBlocking != _fh.wasNonBlocking))
		[self _setNonBlocking: _fh.wasNonBlocking];

	[_note release];
	[_description release];
	[_writeInfo release];

	[super dealloc];
}
													// Returning file handles
- (int) fileDescriptor							{ return _descriptor; }

- (void) _checkRead
{
	if (_fh.readOK == NO)
		[NSException raise: NSFileHandleOperationException
					 format: @"read not permitted on this file handle"];
	if (_note)
		{
		id operation = [_note objectForKey: NotificationKey];

		if (operation == NSFileHandleConnectionAcceptedNotification)
			[NSException raise: NSFileHandleOperationException
						 format: @"accept already in progress"];
		else
			[NSException raise: NSFileHandleOperationException
						 format: @"read already in progress"];
		}
}

- (NSData*) availableData						// Synchronous I/O operations
{
	char buf[MAX_IO_SIZE];
	NSMutableData *d;
	int len;

	[self _checkRead];
	if (_fh.isNonBlocking == YES)
		[self _setNonBlocking: NO];
	d = [NSMutableData dataWithCapacity: 0];

	if (_fh.isRegularFile)
		{
		while ((len = read(_descriptor, buf, sizeof(buf))) > 0)
			[d appendBytes: buf length: len];
		}
	else
		{
		int count = sizeof(buf);

		if ((len = read(_descriptor, buf, count)) > 0)
			[d appendBytes: buf length: len];
		}

	if (len < 0)
		[NSException raise: NSFileHandleOperationException
					 format: @"read from handle failed - %s", strerror(errno)];
	return d;
}

- (NSData*) readDataToEndOfFile
{
	char buf[MAX_IO_SIZE];
	NSMutableData *d;
	int len;

	[self _checkRead];
	if (_fh.isNonBlocking == YES)
		[self _setNonBlocking: NO];
	d = [NSMutableData dataWithCapacity: 0];

	while ((len = read(_descriptor, buf, sizeof(buf))) > 0)
		[d appendBytes: buf length: len];

	if (len < 0)
		[NSException raise: NSFileHandleOperationException
					 format: @"read from handle failed - %s", strerror(errno)];
	return d;
}

- (NSData*) readDataOfLength:(unsigned)len
{
	NSMutableData *d;
	int got;

	[self _checkRead];
	if (_fh.isNonBlocking == YES)
		[self _setNonBlocking: NO];

	if (len <= 65536)
		{
		char *buf = malloc(len);

		d = [NSMutableData dataWithBytesNoCopy: buf length: len];
		if ((got = read(_descriptor, [d mutableBytes], len)) < 0)
			[NSException raise: NSFileHandleOperationException
					 	 format: @"read from handle failed - %s", strerror(errno)];

		[d setLength: got];
		}
	else
		{
		char buf[MAX_IO_SIZE];

		d = [NSMutableData dataWithCapacity: 0];
		do {
			int chunk = len > sizeof(buf) ? sizeof(buf) : len;

			if ((got = read(_descriptor, buf, chunk)) > 0)
				{
				[d appendBytes: buf length: got];
				len -= got;
				}
			else 
				if (got < 0)
					[NSException raise: NSFileHandleOperationException
					 	 		 format: @"read from handle failed - %s", strerror(errno)];
			}
		while (len > 0 && got > 0);
		}

	return d;
}

- (void) writeData:(NSData*)item
{
	int nw = 0;
	const void *ptr = [item bytes];
	NSUInteger len = [item length];
	NSUInteger pos = 0;

	if (_fh.writeOK == NO)
		[NSException raise: NSFileHandleOperationException
					 format: @"write not permitted in this file handle"];

	if (_fh.awaitConnect)
		[NSException raise: NSFileHandleOperationException
					 format: @"connect already in progress"];

	if (_fh.isNonBlocking == YES)
		[self _setNonBlocking: NO];

	while (pos < len)
		{
		int	toWrite = len - pos;
	
		if (toWrite > MAX_IO_SIZE)
			toWrite = MAX_IO_SIZE;

		if ((nw = write(_descriptor, (char*)ptr+pos, toWrite)) < 0)
			break;
		pos += nw;
		}

	if (nw < 0)
		[NSException raise:NSFileHandleOperationException
					 format:@"unable to write to handle - %s",strerror(errno)];
}

- (void) _watchReadDescriptorForModes:(NSArray*)modes
{
	if (_descriptor >= 0)
		{
		CFRunLoopRef rl = CFRunLoopGetCurrent();
		CFOptionFlags fl = kCFSocketReadCallBack;
		CFSocketContext cx = { 0, self, NULL, NULL, NULL };
		SEL scb = @selector(_readDescriptorReady:);
		CFSocketCallBack cb = (CFSocketCallBack)scb;
		CFRunLoopSourceRef rs;
		int i, count;

		_cfSocket = CFSocketCreateWithNative(NULL, _descriptor, fl, cb, &cx);

		[self _setNonBlocking: YES];
		if ((rs = CFSocketCreateRunLoopSource(NULL, _cfSocket, 0)) == NULL)
			[NSException raise:NSGenericException format:@"CFSocket init error"];
		if (modes && (count = [modes count]))
			{
			for (i = 0; i < count; i++)
				{
				CFStringRef m = (CFStringRef)[modes objectAtIndex: i];

				CFRunLoopAddSource(rl, rs, m);
				}

			[_note setObject: modes 
					  forKey: NSFileHandleNotificationMonitorModes];
			}
		else
			CFRunLoopAddSource(rl, rs, (CFStringRef)NSDefaultRunLoopMode);
		CFRelease(rs);
		}
}
												// Asynchronous I/O operations
- (void) acceptConnectionInBackgroundAndNotifyForModes:(NSArray*)modes
{
	if (_fh.acceptOK == NO)
		[NSException raise: NSFileHandleOperationException
					 format: @"accept not permitted on this file handle"];
	if (_note)
		{
		id operation = [_note objectForKey: NotificationKey];

		if (operation == NSFileHandleConnectionAcceptedNotification)
			[NSException raise: NSFileHandleOperationException
						 format: @"accept already in progress"];
		else
			[NSException raise: NSFileHandleOperationException
						 format: @"read already in progress"];
		}

	[_note release];
	_note = [[NSMutableDictionary dictionaryWithCapacity: 4] retain];
	[_note setObject: NSFileHandleConnectionAcceptedNotification
			  forKey: NotificationKey];
	[self _watchReadDescriptorForModes: modes];
}

- (void) readInBackgroundAndNotifyForModes:(NSArray*)modes
{
	[self _checkRead];
	[_note release];
	_note = [[NSMutableDictionary dictionaryWithCapacity: 4] retain];
	[_note setObject: NSFileHandleReadCompletionNotification
			  forKey: NotificationKey];
	[_note setObject: [NSMutableData dataWithCapacity: 0]
			  forKey: NSFileHandleNotificationDataItem];
	[self _watchReadDescriptorForModes: modes];
}

- (void) readToEndOfFileInBackgroundAndNotifyForModes:(NSArray*)modes
{
	[self _checkRead];
	[_note release];
	_note = [[NSMutableDictionary dictionaryWithCapacity: 4] retain];
	[_note setObject: NSFileHandleReadToEndOfFileCompletionNotification
			  forKey: NotificationKey];
	[_note setObject: [NSMutableData dataWithCapacity: 0]
			  forKey: NSFileHandleNotificationDataItem];
	[self _watchReadDescriptorForModes: modes];
}

- (void) waitForDataInBackgroundAndNotifyForModes:(NSArray*)modes
{
	[self _checkRead];
	[_note release];
	_note = [[NSMutableDictionary dictionaryWithCapacity: 4] retain];
	[_note setObject: NSFileHandleDataAvailableNotification
			  forKey: NotificationKey];
	[_note setObject: [NSMutableData dataWithCapacity: 0]
			  forKey: NSFileHandleNotificationDataItem];
	[self _watchReadDescriptorForModes: modes];
}

- (void) acceptConnectionInBackgroundAndNotify
{
	[self acceptConnectionInBackgroundAndNotifyForModes: nil];
}

- (void) readInBackgroundAndNotify
{
	return [self readInBackgroundAndNotifyForModes: nil];
}

- (void) readToEndOfFileInBackgroundAndNotify
{
	return [self readToEndOfFileInBackgroundAndNotifyForModes: nil];
}

- (void) waitForDataInBackgroundAndNotify
{
	return [self waitForDataInBackgroundAndNotifyForModes: nil];
}

- (unsigned long long) offsetInFile					// Seeking within a file
{
	off_t result = -1;

	if (_fh.isRegularFile && _descriptor >= 0)
		result = lseek(_descriptor, 0, SEEK_CUR);
	if (result < 0)
		[NSException raise: NSFileHandleOperationException
					 format: @"seek to offset failed - %s", strerror(errno)];

	return (unsigned long long)result;
}

- (unsigned long long) seekToEndOfFile
{
	off_t result = -1;

	if (_fh.isRegularFile && _descriptor >= 0)
		result = lseek(_descriptor, 0, SEEK_END);
	if (result < 0)
		[NSException raise: NSFileHandleOperationException
					 format: @"seek to offset failed - %s", strerror(errno)];

	return (unsigned long long)result;
}

- (void) seekToFileOffset:(unsigned long long)pos
{
	off_t result = -1;

	if (_fh.isRegularFile && _descriptor >= 0)
		result = lseek(_descriptor, (off_t)pos, SEEK_SET);
	if (result < 0)
		[NSException raise: NSFileHandleOperationException
					 format: @"seek to offset failed - %s", strerror(errno)];
}

- (void) closeFile										// Operations on file
{
	if (_descriptor < 0)
		[NSException raise: NSFileHandleOperationException
					 format: @"attempt to close invalid file handle"];
	if (_cfSocket)
		CFSocketInvalidate(_cfSocket), _cfSocket = NULL;
	else if (close(_descriptor) != 0)
		NSLog(@"error closing file handle - %s", strerror(errno));

	_descriptor = -1;
	_fh.acceptOK = _fh.connectOK = _fh.readOK = _fh.writeOK = NO;
}

- (void) synchronizeFile
{
	if (_fh.isRegularFile)
		(void)sync();
}

- (void) truncateFileAtOffset:(unsigned long long)pos
{
	if (_fh.isRegularFile && _descriptor >= 0)
		(void)ftruncate(_descriptor, pos);
	[self seekToFileOffset: pos];
}

@end

/* ****************************************************************************

	NSPipe

** ***************************************************************************/

@implementation NSPipe

+ (id) pipe
{
    return [[[NSPipe alloc] init] autorelease];
}

- (id) init
{
	int fd[2];

	if (pipe2(fd, O_CLOEXEC) == -1)
		return _NSInitError(self, @"pipe() failed: %s", strerror(errno));

    _readFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd[0]
											closeOnDealloc:YES];
    _writeFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd[1]
											 closeOnDealloc:YES];
    return self;
}

- (void) dealloc
{
	[_readFileHandle release];
	[_writeFileHandle release];
    [super dealloc];
}

- (NSFileHandle*) fileHandleForReading		{ return _readFileHandle; }
- (NSFileHandle*) fileHandleForWriting		{ return _writeFileHandle; }

@end  /* NSPipe */
