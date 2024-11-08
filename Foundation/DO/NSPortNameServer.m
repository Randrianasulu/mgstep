/*
   NSPortNameServer.m

   Port registration service used by the DO system.

   Copyright (C) 1998 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	October 1998

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#if	!defined(__WIN32__) || defined(__CYGWIN__)
	#include <netinet/in.h>							// for inet_ntoa()
	#include <arpa/inet.h>
#endif /* !__WIN32__ */

#include <Foundation/NSPortNameServer.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSData.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSPort.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRunLoop.h>

#include <CoreFoundation/CFRunLoop.h>

#include "Stream.h"
#include "domap.h"						// domap Protocol definition

#include <sys/file.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/ioctl.h>

#include <netdb.h>

			// stringify the result of expanding a macro argument
#define STRINGIFY(s)	#s
#define STR_EXPAND(s)	STRINGIFY(s)

#define WRITE_TIMEOUT	[NSDate dateWithTimeIntervalSinceNow: __writeTimeout]
#define READ_TIMEOUT	[NSDate dateWithTimeIntervalSinceNow: __readTimeout]

														// mGSTEP Notifications
extern NSString *_FileHandleConnectCompletionNotification;
extern NSString *_FileHandleWriteCompletionNotification;


// Class variables
static NSTimeInterval __writeTimeout = 5.0;
static NSTimeInterval __readTimeout = 15.0;
static NSTimeInterval connectTimeout = 20.0;
static NSString *__serverPort = @"domap";
static NSString *mode = @"NSPortServerLookupMode";
static NSArray *__modes = nil;
static NSRecursiveLock *__serverLock = nil;
static NSPortNameServer *__defaultPortNameServer = nil;



@interface NSPortNameServer (Private)						// Private methods

- (void) _close;
- (void) _didConnect:(NSNotification*)notification;
- (void) _didRead:(NSNotification*)notification;
- (void) _didWrite:(NSNotification*)notification;
- (void) _open:(NSString*)host;
- (void) _retry;

@end


@implementation NSPortNameServer

+ (id) alloc
{
	[NSException raise: NSGenericException
				 format: @"attempt to create extra port name server"]; 
	return nil;
}

+ (void) initialize
{
	if (self == [NSPortNameServer class] && __serverLock == nil)
		{
		__serverLock = [NSRecursiveLock new];
		__modes = [[NSArray alloc] initWithObjects: &mode count: 1];
#ifdef DOMAP_PORT_OVERRIDE
		__serverPort = [[NSString stringWithCString:
							STR_EXPAND(DOMAP_PORT_OVERRIDE)] retain];
#endif
		}
}

+ (id) defaultPortNameServer
{
	if (__defaultPortNameServer == nil)
		{
		[__serverLock lock];

		if (__defaultPortNameServer == nil)
			{
			NSPortNameServer *s = (NSPortNameServer*)NSAllocateObject(self);

			s->data = [NSMutableData new];
			s->portMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
										NSObjectMapValueCallBacks, 0);
			s->nameMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
			__defaultPortNameServer = s;
			}
		[__serverLock unlock];
		}

	return __defaultPortNameServer;
}

- (void) dealloc
{
	[NSException raise: NSGenericException
				 format: @"attempt to deallocate default port name server"];
	NO_WARN;
}

- (NSPort*) portForName:(NSString*)name
{
	return [self portForName: name onHost: nil];
}

- (NSPort*) portForName:(NSString*)name onHost:(NSString*)host
{
	do_req msg;										// Message structure.
	NSMutableData *dat;									// Hold message here.
	unsigned len;
	NSRunLoop *loop = [NSRunLoop currentRunLoop];
	struct in_addr singleServer;
	struct in_addr *svrs = &singleServer;
	unsigned numSvrs;
	unsigned count;
	unsigned portNum = 0;

	if (name == nil)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to register port with nil name"]; 

	if ((len = [name cStringLength]) == 0)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to register port with no name"]; 

	if (len > GDO_NAME_MAX_LEN)
		[NSException raise: NSInvalidArgumentException
					 format: @"name of port is too long (max %d) bytes",
								GDO_NAME_MAX_LEN]; 

	if (host != nil && [host isEqual: @"*"])
		{
		NSMutableData *tmp;
		unsigned bufsiz;
		unsigned length;

		msg.rtype = GDO_SERVERS;				// Get a list of name servers.
		msg.ptype = GDO_TCP_GDO;				// Port is TCP port for GNU DO
		msg.nsize = 0;
		msg.port = 0;
		dat = [NSMutableData dataWithBytes:(void*)&msg length: sizeof(msg)];

		[__serverLock lock];
		NS_DURING
			{
			[self _open: nil];
			_expecting = sizeof(msg);

			[handle writeInBackgroundAndNotify: dat forModes: __modes];

			[loop runMode: mode beforeDate:WRITE_TIMEOUT];
			if (_expecting)
				[NSException raise: NSPortTimeoutException
							 format: @"timed out writing to domap"]; 
		
			_expecting = sizeof(unsigned);
			[data setLength: 0];
			[handle readInBackgroundAndNotifyForModes: __modes];
			[loop runMode: mode beforeDate:READ_TIMEOUT];
			if (_expecting)
				[NSException raise: NSPortTimeoutException
							 format: @"timed out reading from domap"]; 

			numSvrs = NSSwapBigIntToHost(*(unsigned*)[data bytes]);
			if (numSvrs == 0)
				[NSException raise: NSInternalInconsistencyException
							 format: @"failed to get list of name servers"];
		
							// Calculate size of buffer for server internet 
							// addresses and allocate a buffer to store them in
			bufsiz = numSvrs * sizeof(struct in_addr);
			tmp = [NSMutableData dataWithLength: bufsiz];
			svrs = (struct in_addr*)[tmp mutableBytes];
		
						// Read the addresses from the name server if necessary
						// and copy them to our newly allocated buffer. We may 
						// already have some/all of the data, in which case
						// we don't need to do a read.
			length = [data length] - sizeof(unsigned);
			if (length > 0)
				{
				void *bytes = [data mutableBytes];
		
				memcpy(bytes, bytes+sizeof(unsigned), length);
				[data setLength: length];
				}
			else
				[data setLength: 0];
		
			if (length < bufsiz)
				{
				_expecting = bufsiz;
				[handle readInBackgroundAndNotifyForModes: __modes];
				[loop runMode: mode beforeDate:READ_TIMEOUT];
				if (_expecting)
					[NSException raise: NSPortTimeoutException
								 format: @"timed out reading from domap"]; 
				}
		
			[data getBytes:(void*)svrs length: bufsiz];
			[self _close];
			}
		NS_HANDLER
			{					// If we had a problem unlock before continuing
			[self _close];
			[__serverLock unlock];
			[localException raise];
			}
		NS_ENDHANDLER

		[__serverLock unlock];
		}
	else
		{						// Query a single nameserver on the local host.
		numSvrs = 1;
#ifndef HAVE_INET_ATON
		svrs->s_addr = inet_addr("127.0.0.1");
#else
		inet_aton("127.0.0.1", &svrs->s_addr);
#endif
		}

	[__serverLock lock];
	NS_DURING
    	{
		for (count = 0; count < numSvrs; count++)
			{
			NSString *addr;
	
			msg.rtype = GDO_LOOKUP;						// Find the named port.		
			msg.ptype = GDO_TCP_GDO;			// Port is TCP port for GNU DO
			msg.port = 0;
			msg.nsize = len;
			[name getCString:msg.name maxLength:GDO_NAME_MAX_LEN];
			dat = [NSMutableData dataWithBytes:(void*)&msg length:sizeof(msg)];
	
			addr = [NSString stringWithCString: inet_ntoa(svrs[count])];
			[self _open: addr];
			_expecting = sizeof(msg);
			[handle writeInBackgroundAndNotify: dat forModes: __modes];
			[loop runMode: mode beforeDate: WRITE_TIMEOUT];

			if (_expecting)
				[self _close];
			else
				{
				_expecting = sizeof(unsigned);
				[data setLength: 0];
				[handle readInBackgroundAndNotifyForModes: __modes];
				[loop runMode: mode beforeDate: READ_TIMEOUT];
				[self _close];
				if (_expecting == 0)
					{
					portNum = NSSwapBigIntToHost(*(unsigned*)[data bytes]);
					if (portNum != 0)
						break;
		}	}	}	}
	NS_HANDLER
		{						// If we had a problem unlock before continuing
		[self _close];
		[__serverLock unlock];
		[localException raise];
		}
	NS_ENDHANDLER

	[__serverLock unlock];

	if (portNum)
		return [NSPort _newOutPortWithPortNumber: portNum
					   andAddress:svrs[count]];
	return nil;
}

- (BOOL) registerPort:(NSPort*)port forName:(NSString*)name
{
	do_req	msg;											// Message structure.
	NSMutableData *dat;										// Hold message here.
	unsigned len;
	NSRunLoop *loop = [NSRunLoop currentRunLoop];

	if (name == nil)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to register port with nil name"]; 

	if (port == nil)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to register nil port"]; 
	
	if ((len = [name cStringLength]) == 0)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to register port with no name"]; 

	if (len > GDO_NAME_MAX_LEN)
		[NSException raise: NSInvalidArgumentException
					 format: @"name of port is too long (max %d) bytes",
								GDO_NAME_MAX_LEN]; 

	[__serverLock lock];	// Lock out other threads while doing I/O to domap

	NS_DURING
		{
		NSMutableSet *known = NSMapGet(portMap, port);

					// If there is no set of names for this port create one.
		if (known == nil)
			{
			known = [NSMutableSet new];
			NSMapInsert(portMap, port, known);
			[known release];
			}
				// If this port has never been registered under any name, first
				// send an unregister message to domap to ensure that any 
				// old names for the port (perhaps from a server that crashed
				// without unregistering its ports) are no longer around.
		if ([known count] == 0)
			{
			msg.rtype = GDO_UNREG;
			msg.ptype = GDO_TCP_GDO;
			msg.nsize = 0;
			msg.port = NSSwapHostIntToBig([port portNumber]);
			dat = [NSMutableData dataWithBytes:(void*)&msg length:sizeof(msg)];
	
			[self _open: nil];
	
			_expecting = sizeof(msg);
			[handle writeInBackgroundAndNotify: dat forModes: __modes];
			[loop runMode: mode beforeDate: WRITE_TIMEOUT];
			if (_expecting)
				[NSException raise: NSPortTimeoutException
							 format: @"timed out writing to domap"]; 
	
					// Queue a read request in our own run mode then run until
					// the timeout period or until the read completes.
			_expecting = sizeof(unsigned);
			[data setLength: 0];
			[handle readInBackgroundAndNotifyForModes: __modes];
			[loop runMode: mode beforeDate: READ_TIMEOUT];
			if (_expecting)
				[NSException raise: NSPortTimeoutException
							 format: @"timed out reading from domap"]; 
	
			if ([data length] != sizeof(unsigned))
				[NSException raise: NSInternalInconsistencyException
							 format: @"too much data read from domap"]; 

			[self _close];
			}

		msg.rtype = GDO_REGISTER;	/* Register a port.		*/
		msg.ptype = GDO_TCP_GDO;	/* Port is TCP port for GNU DO	*/
		msg.nsize = len;
		[name getCString:msg.name maxLength:GDO_NAME_MAX_LEN];
		msg.port = NSSwapHostIntToBig((unsigned)[port portNumber]);
		dat = [NSMutableData dataWithBytes:(void*)&msg length: sizeof(msg)];

		[self _open: nil];
						// Queue a write request in our own run mode then run 
						// until the timeout period or until write completes.
		_expecting = sizeof(msg);
		[handle writeInBackgroundAndNotify: dat forModes: __modes];
		[loop runMode: mode beforeDate: WRITE_TIMEOUT];
		if (_expecting)
			[NSException raise: NSPortTimeoutException
						 format: @"timed out writing to domap"]; 

					// Queue a read request in our own run mode then run until 
					// the timeout period or until the read completes.
		_expecting = sizeof(unsigned);
		[data setLength: 0];
		[handle readInBackgroundAndNotifyForModes: __modes];
		[loop runMode: mode beforeDate: READ_TIMEOUT];
		if (_expecting)
			[NSException raise: NSPortTimeoutException
						 format: @"timed out reading from domap"]; 

		if ([data length] != sizeof(unsigned))
			[NSException raise: NSInternalInconsistencyException
						 format: @"too much data read from domap"]; 
		else
			{
//			unsigned db = *(unsigned int *)[data bytes];
			unsigned result = NSSwapBigIntToHost(*(unsigned*)[data bytes]);
//			unsigned result = NSSwapBigIntToHost(db);

printf("db %d result %d\n", *(unsigned*)[data bytes], result);
			if (result == 0)
				[NSException raise: NSGenericException
							 format: @"unable to register %@", name]; 
			else
				{					// Add this name to the set of names that 
									// the port is known by and to the name map
				[known addObject: name];
				NSMapInsert(nameMap, name, port);
		}	}	}
	NS_HANDLER
		{					// If we had a problem unlock before continuing
		[self _close];
		[__serverLock unlock];
		[localException raise];
		}
	NS_ENDHANDLER

	[self _close];
	[__serverLock unlock];

	return YES;
}

- (void) removePortForName:(NSString*)name
{
	do_req	msg;										// Message structure.
	NSMutableData *dat;									// Hold message here.
	unsigned len;
	NSRunLoop *loop = [NSRunLoop currentRunLoop];

	if (name == nil)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to remove port with nil name"]; 

	if ((len = [name cStringLength]) == 0)
		[NSException raise: NSInvalidArgumentException
					 format: @"attempt to remove port with no name"]; 

	if (len > GDO_NAME_MAX_LEN)
		[NSException raise: NSInvalidArgumentException
					 format: @"name of port is too long (max %d) bytes",
							GDO_NAME_MAX_LEN]; 

	msg.rtype = GDO_UNREG;			// Unregister a port.
	msg.ptype = GDO_TCP_GDO;		// Port is TCP port for GNU DO
	msg.nsize = len;
	[name getCString:msg.name maxLength:GDO_NAME_MAX_LEN];
	msg.port = 0;
	dat = [NSMutableData dataWithBytes:(void*)&msg length: sizeof(msg)];

	[__serverLock lock];		// Lock out other threads while doing domap I/O

	NS_DURING
		{
		[self _open: nil];			// Queue a write request in our own run 
									// mode then run until the timeout period 
		_expecting = sizeof(msg);	// or until the write completes.
		[handle writeInBackgroundAndNotify: dat forModes: __modes];
		[loop runMode: mode beforeDate: WRITE_TIMEOUT];
		if (_expecting)
			[NSException raise: NSPortTimeoutException
						 format: @"timed out writing to domap"]; 

						// Queue a read request in our own run mode then run 
						// until the timeout period or until the read completes
		_expecting = sizeof(unsigned);
		[data setLength: 0];
		[handle readInBackgroundAndNotifyForModes: __modes];
		[loop runMode: mode beforeDate: READ_TIMEOUT];
		if (_expecting)
			[NSException raise: NSPortTimeoutException
						 format: @"timed out reading from domap"]; 

		[self _close];			// Finished with server - so close connection.

		if ([data length] != sizeof(unsigned))
			[NSException raise: NSInternalInconsistencyException
						 format: @"too much data read from domap"]; 
		else
			{
			unsigned result = NSSwapBigIntToHost(*(unsigned*)[data bytes]);

			if (result == 0)
				NSLog(@"NSPortNameServer unable to unregister '%@'\n", name);
			else
				{
				NSPort *port = NSMapGet(nameMap, name);		
								// Find the port that was registered for this 
				if (port)		// name and remove the mapping table entries.
					{
					NSMutableSet *known;
		
					NSMapRemove(nameMap, name);
					if ((known = NSMapGet(portMap, port)))
						{
						[known removeObject: name];
						if ([known count] == 0)
							NSMapRemove(portMap, port);
		}	}	}	}	}
	NS_HANDLER
		{					// If we had a problem unlock before continueing.
		[self _close];
		[__serverLock unlock];
		[localException raise];
		}
	NS_ENDHANDLER

	[__serverLock unlock];
}

- (void) _removePort:(NSPort*)port		// Remove all names for a particular
{										// port.  Called when a port is
	[__serverLock lock];				// invalidated.
	NS_DURING
		{
		NSMutableSet *known = (NSMutableSet*)NSMapGet(portMap, port);
		NSString *name;
	
		while ((name = [known anyObject]) != nil)
			[self removePortForName: name];
		}
	NS_HANDLER
		{
		[__serverLock unlock];
		[localException raise];
		}
	NS_ENDHANDLER

	[__serverLock lock];
}

@end  /* NSPortNameServer */


@implementation	NSPortNameServer (Private)

- (void) _close
{
	if (handle)
		{
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

		[nc removeObserver: self
			name: _FileHandleConnectCompletionNotification
			object: handle];
		[nc removeObserver: self
			name: NSFileHandleReadCompletionNotification
			object: handle];
		[nc removeObserver: self
			name: _FileHandleWriteCompletionNotification
			object: handle];
		[handle closeFile];
		[handle release];
		handle = nil;
		}
}

- (void) _didConnect:(NSNotification*)notification
{
	NSNumber *en = [[notification userInfo] objectForKey:NSFileHandleError];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	int e = [en intValue];

	if (en)
		NSLog(@"NSPortNameServer failed connect to domap - %s", strerror(e)); 
	else		// There should now be nothing for the runloop to do so control
		{		// should return to the method that started the connection.  
				// Set '_expecting' to zero to show that the connection worked 
				// and stop watching for connection completion.
		_expecting = 0;
		[nc removeObserver: self
			name: _FileHandleConnectCompletionNotification
			object: handle];
		}
}

- (void) _didRead:(NSNotification*)notification
{
	NSDictionary *userInfo = [notification userInfo];
	NSData *d = [userInfo objectForKey:NSFileHandleNotificationDataItem];

	if (d == nil || [d length] == 0)
		{
		[self _close];
		[NSException raise: NSGenericException
					 format: @"NSPortNameServer lost connection to domap"]; 
		}
	else
		{
		[data appendData: d];
														// Not enough data read 
		if ([data length] < _expecting)					// go read some more.
			[handle readInBackgroundAndNotifyForModes: __modes];
		else
			_expecting = 0;								// read complete
		}
}

- (void) _didWrite:(NSNotification*)notification
{
	NSNumber *e = [[notification userInfo] objectForKey:NSFileHandleError];

	if (e)
		{
		[self _close];
		[NSException raise: NSGenericException
					 format:@"NSPortNameServer failed write to domap - %s",
							strerror([e intValue])]; 
		}
	else
		_expecting = 0;									// write complete
}

- (void) _open:(NSString*)host
{
	NSRunLoop *loop;
	NSString *hostname = host;
	BOOL isLocal = NO;
	NSNotificationCenter *nc;

	if (handle)
		return;										// Connection already open.	

	if (hostname == nil)
		{
		hostname = @"localhost";
		isLocal = YES;
		}
	else
		{
		NSHost *nshost = [NSHost hostWithName: hostname];

		if (nshost == nil)
			nshost = [NSHost hostWithAddress: hostname];

		if ([[NSHost currentHost] isEqual: nshost])
			isLocal = YES;
		}

	NS_DURING
		handle = [NSFileHandle fileHandleAsClientInBackgroundAtAddress:host
							   service:__serverPort
							   protocol:@"tcp"
							   forModes:__modes];
	NS_HANDLER
		{
		if ([[localException name] isEqual: NSInvalidArgumentException])
			{
			NSLog(@"Exception looking up port for domap %@\n",localException);
			handle = nil;
			}
		else
			[localException raise];
		}
  NS_ENDHANDLER

	if (handle == nil)
		{
		NSLog(@"Failed to find domap port with name '%@',\nperhaps your "
				@"/etc/services file is not correctly set up?\n"
				@"Retrying with default (IANA allocated) port number 538",
				__serverPort);

		NS_DURING
			handle = [NSFileHandle fileHandleAsClientInBackgroundAtAddress:host
								   service: @"538"
								   protocol: @"tcp"
								   forModes: __modes];
		NS_HANDLER
			[localException raise];
		NS_ENDHANDLER
			if (handle)
				{
				[__serverPort release];
				__serverPort = @"538";
				}
		}

	if (handle == nil)
		[NSException raise: NSGenericException
					 format: @"failed to create file handle to domap on %@",
							hostname];

	_expecting = 1;
	[handle retain];
	nc = [NSNotificationCenter defaultCenter];		 
	[nc addObserver: self
		selector: @selector(_didConnect:)
		name: _FileHandleConnectCompletionNotification
		object: handle];
	[nc addObserver: self
		selector: @selector(_didRead:)
		name: NSFileHandleReadCompletionNotification
		object: handle];
	[nc addObserver: self
		selector: @selector(_didWrite:)
		name: _FileHandleWriteCompletionNotification
		object: handle];
	loop = [NSRunLoop currentRunLoop];
	[loop runMode: mode
		  beforeDate: [NSDate dateWithTimeIntervalSinceNow: connectTimeout]];
	if (_expecting)
		{
		static BOOL retrying = NO;

		[self _close];
		if (isLocal == YES && retrying == NO)
			{
			retrying = YES;
			NS_DURING
				[self _retry];
			NS_HANDLER
				{
				retrying = NO;
				[localException raise];
				}
			NS_ENDHANDLER
			retrying = NO;
			}
		else
			{
			if (isLocal)
				NSLog(@"NSPortNameServer failed to connect to domap - %s",
						"make sure that domap is running and owned by root."); 
			else
				NSLog(@"NSPortNameServer failed to connect to domap on %@",
						hostname);
		}	}
}

- (void) _retry
{
	static NSString	*cmd = nil;
	NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 5.0];

	if (cmd == nil)
		{
		cmd = [[NSBundle systemBundle] bundlePath];
		cmd = [cmd stringByAppendingString:@"/Foundation/DO/domap"];
		}
	NSLog(@"NSPortNameServer attempting to start domap on local host"); 
	[NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
	[NSTimer scheduledTimerWithTimeInterval:5.0 invocation:nil repeats:NO];
	[[NSRunLoop currentRunLoop] runUntilDate: date];
	NSLog(@"NSPortNameServer retrying connection attempt to domap"); 
	[self _open: nil];
}

@end  /* NSPortNameServer (Private) */
