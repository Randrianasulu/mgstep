/*
   NSPort.m

   Port classes for use with NSConnection

   Copyright (C) 1997-2016 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	July 1994
   Rewrite: Richard Frith-Macdonald <richard@brainstorm.co.u>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSPort.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSPortMessage.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSRunLoop.h>
#include "_NSPortCoder.h"
#include "Stream.h"
#include <Foundation/NSPortNameServer.h>

#include <CoreFoundation/CFRunLoop.h>
#include <CoreFoundation/CFSocket.h>

#if	!defined(__WIN32__) || defined(__CYGWIN__)
  #include <sys/param.h>							// for MAXHOSTNAMELEN
  #include <netinet/in.h>							// for inet_ntoa()
  #include <arpa/inet.h>
  #include <netdb.h>
  #include <fcntl.h>
  #include <sys/socket.h>
  #include <sys/file.h>
#endif /* !__WIN32__ */

#include <signal.h>
#include <resolv.h>



NSString *NSPortDidBecomeInvalidNotification = @"NSPortDidBecomeInvalidNotification";
NSString *NSPortTimeoutException = @"NSPortTimeoutException";

extern struct __res_state _res;				// defined in resolv.h

// Class variables
static int debug_tcp_port = 0;
static NSMapTable *out_port_bag = NULL;
static NSMapTable *socket_2_port = NULL;	// Both TcpInPort's + TcpOutPort's 
											// are entered in this maptable

static NSMapTable *port_number_2_port;		// This map table is used to make 
											// sure we don't create more than 
											// one TcpInPort listening to the 
											// same port number.
@interface TcpInPort : NSPort
{											// concrete implementation of a 
	int _port_socket;						// Port object implemented on top 
	struct sockaddr_in _listening_address;	// of SOCK_STREAM connections.
	NSMapTable *_client_sock_2_out_port;
	NSMapTable *_client_sock_2_packet;
	id _packet_invocation;
}

+ (id) newForReceivingFromPortNumber:(unsigned short)n;

- (int) portNumber;
- (unsigned) numberOfConnectedOutPorts;
- (void) _receivedEvent:(void*)data						// called by NSRunLoop 
				   type:(CFSocketCallBackType)type		// when select() says
				   extra:(const void*)extra				// the fd is ready
				   forMode:(NSString*)mode;
@end


@interface TcpOutPort : NSPort
{
	int _port_socket;
							// address of the listen()'ing socket of the remote
							// TcpInPort we are connected to, not the address 
							// of the _port_socket ivar.
	struct sockaddr_in _remote_in_port_address;
	struct sockaddr_in _peer_address;	// address of our remote peer socket

	id _polling_in_port;				// TcpInPort that is polling our 
}										// _port_socket with select()

+ (id) newForSendingToSockaddr:(struct sockaddr_in*)sockaddr 
			withAcceptedSocket:(int)sock
			pollingInPort:ip;
- (int) portNumber;

@end


@interface NSConnection (Private)

+ (void) invokeWithObject:(id)packet;

@end


static void
_PortCallback( CFSocketRef s,
			   CFSocketCallBackType type,
			   CFDataRef address,
			   const void *data,
			   void *clientCallBackInfo)
{
	TcpInPort *p = (TcpInPort *)clientCallBackInfo;

	[p _receivedEvent:NULL type:type extra:data forMode:nil];
}

@implementation NSPort

+ (void) initialize
{
	if (self == [NSPort class])
		{
		socket_2_port = NSCreateMapTable (NSIntMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
		out_port_bag = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
		port_number_2_port = NSCreateMapTable (NSIntMapKeyCallBacks,
			  							NSNonOwnedPointerMapValueCallBacks, 0);

		signal(SIGPIPE, SIG_IGN);	// If SIGPIPE is not ignored, we will abort
		}							// on any attempt to write to a pipe/socket
}									// that has been closed by the other end!

+ (NSPort*) port						{ return [[NSPort new] autorelease]; }
+ (void) _setDebug:(int)val				{ debug_tcp_port = val; }
+ (Class) _outPortClass					{ return [TcpOutPort class]; }
+ (Class) _inPortClass					{ return [TcpInPort class]; }

+ (id) _newForReceivingFromPortNumber:(unsigned short)pn
{
	return [TcpInPort newForReceivingFromPortNumber: pn];
}

+ (id) _newForSendingToSockaddr:(struct sockaddr_in*)sockaddr 
			 withAcceptedSocket:(int)sock
			 pollingInPort:ip
{
	return [TcpOutPort newForSendingToSockaddr: sockaddr
					   withAcceptedSocket:sock
					   pollingInPort:ip];
}

+ (id) _newOutPortWithPortNumber:(unsigned)portNum 
					  andAddress:(struct in_addr)address
{
	struct sockaddr_in sin;
	NSPort *p;
	unsigned short n;

	memset(&sin, '\0', sizeof(sin));
	sin.sin_family = AF_INET;

					// The returned port is an unsigned int - so we have to
					// convert to a short in network byte order big endian
	n = (unsigned short)portNum;
	sin.sin_port = NSSwapHostShortToBig(n);

					// The host addresses are given to us in network byte 
					// order so we just copy the address into place.
	sin.sin_addr.s_addr = address.s_addr;

	p = [TcpOutPort newForSendingToSockaddr: &sin
					withAcceptedSocket: 0
					pollingInPort: nil];

	return [p autorelease];
}

- (id) init
{
	_is_valid = YES;

	return [super init];
}
										// subclasses should override this  
- (void) invalidate						// method and call [super invalidate]  
{										// in their versions of the method.
	[[NSPortNameServer defaultPortNameServer] _removePort: self];
	_is_valid = NO;
	[NSNotificationCenter post:NSPortDidBecomeInvalidNotification object:self];
}

- (void) release
{
	if (_is_valid && [self retainCount] == 1)
		{
		NSAutoreleasePool *arp;
				// If the port is about to have a final release deallocate it
				// we must invalidate it.  Use a local autorelease pool when
				// invalidating so that we know that anything refering to this
				// port during the invalidation process is released immediately
				// Also bracket with retain/release pair to prevent recursion.
		[super retain];
		arp = [NSAutoreleasePool new];
		[self invalidate];
		[arp release];
		[super release];
		}
	[super release];
}

- (void) addConnection:(NSConnection*)connection		// add receiver to rl
			 toRunLoop:(NSRunLoop*)runLoop				// on behalf of its
			 forMode:(NSString*)mode					// connection
{
	[self setDelegate:connection];
	[self scheduleInRunLoop:runLoop forMode:mode];
}

- (void) removeConnection:(NSConnection*)connection
			  fromRunLoop:(NSRunLoop*)runLoop
			  forMode:(NSString*)mode
{
	[self removeFromRunLoop:runLoop forMode:mode];
	[self setDelegate:nil];
}

- (void) scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode
{
	CFRunLoopSourceRef rs;

	if ((rs = CFSocketCreateRunLoopSource(NULL, _cfSocket, 0)) == NULL)
		[NSException raise:NSGenericException format:@"CFSocket init error"];
	CFRunLoopAddSource((CFRunLoopRef)rl, rs, (CFStringRef)mode);
	CFRelease(rs);
}

- (void) removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode
{
	CFSocket *s = (CFSocket *)_cfSocket;
	CFRunLoopSourceRef rs = (CFRunLoopSourceRef)s->runLoopSource;

	CFRunLoopRemoveSource((CFRunLoopRef)rl, rs, kCFRunLoopCommonModes);
}

- (void) setDelegate:(id)anObject
{
	NSAssert([anObject respondsToSelector: @selector(handlePortMessage:)],
				NSInvalidArgumentException);
	_delegate = anObject;
}

- (id) copy								{ return [self retain]; }
- (id) delegate							{ return _delegate; }
- (BOOL) isValid						{ return _is_valid; }
- (void) close							{ [self invalidate]; }
- (Class) classForPortCoder				{ return [self class]; }

- (void) encodeWithCoder:(NSCoder *)ec	{ [super encodeWithCoder:ec]; }
- (id) initWithCoder:(NSCoder *)dc		{ return [super initWithCoder:dc]; }

- (id) replacementObjectForPortCoder:(NSPortCoder*)coder	{ return self; }

@end  /* NSPort */


@interface TcpInPort (Private)

- (int) _portSocket;
- (void) _addClientOutPort:(id)p;
- (void) _connectedOutPortInvalidated:(id)p;
- (id) _tryToGetPacketFromReadableFD:(int)fd_index;

@end


@interface TcpOutPort (Private)

- (int) _portSocket;
- (id) _initWithSocket:(int)s inPort:ip;
+ (id) _newWithAcceptedSocket:(int)s peeraddr:(struct sockaddr_in*)a inPort:p;

@end

/* ****************************************************************************

	TcpInPort

	An obj that represents a listen()'ing socket, and a collection of socket's
	which the NSRunLoop will poll using select().  Each of the socket's that 
	is polled is actually held by a TcpOutPort object.  See TcpOutPort comments.

** ***************************************************************************/

@implementation TcpInPort			// designated initializer.  If 'n' is zero
									// a port is chosen automagically.
+ (id) newForReceivingFromPortNumber:(unsigned short)n
{
	TcpInPort *p;					// If there's already a TcpInPort listening
									// to this port number, return it
	if ((p = (id) NSMapGet (port_number_2_port, UINT2PTR(n))))
		{
		NSAssert(p->_is_valid, NSInternalInconsistencyException);

		return [p retain];
		}
									// There isn't already a TcpInPort for this
	p = [[TcpInPort alloc] init];	// port number, so create a new port object
	p->_port_socket = socket (AF_INET, SOCK_STREAM, 0);	   // Create the socket

	if (p->_port_socket < 0)
		{
		[p release];
		[NSException raise: NSInternalInconsistencyException
		format: @"[TcpInPort +newForReceivingFromPortNumber:] socket(): %s",
		strerror(errno)];
		}
						// Register the port object according to its socket.
	NSAssert(!NSMapGet (socket_2_port, INT2PTR(p->_port_socket)), 	
				NSInternalInconsistencyException);
	NSMapInsert (socket_2_port, INT2PTR(p->_port_socket), p);
  
				// Give the socket a name using bind() and INADDR_ANY for the
				// machine address in _LISTENING_ADDRESS; then put the network
				// address of this machine in _LISTENING_ADDRESS.SIN_ADDR, so
	{			// that when we encode the address, another machine can find us
    struct hostent *hp;
    char hostname[MAXHOSTNAMELEN], *first_dot;
    int len = MAXHOSTNAMELEN;
    int	r = 1;		// Set the re-use socket option so that we don't get this 
					// socket hanging around after we close it (or die)
	setsockopt(p->_port_socket, SOL_SOCKET, SO_REUSEADDR,(char*)&r,sizeof(r));

			// Fill in the _LISTENING_ADDRESS with the address this in port on
			// which will listen for connections.  Use INADDR_ANY so that we
			// will accept connection on any of the machine network addresses;
			// most machine will have both an Internet address, and the
			// "localhost" address (i.e. 127.0.0.1)
    p->_listening_address.sin_addr.s_addr = NSSwapBigIntToHost(INADDR_ANY);
    p->_listening_address.sin_family = AF_INET;
    p->_listening_address.sin_port = NSSwapHostShortToBig (n);

					// if 'n' is zero, bind() will choose a port number for us.
    if (bind (p->_port_socket, (struct sockaddr*) &(p->_listening_address),
	      sizeof (p->_listening_address)) < 0)
		{
		BOOL ok = NO;			// bind() sometimes seems to fail when given  
								// a port of zero - this should really never   
		if (n == 0) 			// happen, so we retry a few times in case the
			{					// kernel has had a temporary brainstorm.
			int count;

			for (count = 0; count < 10; count++) 
				{
				memset(&p->_listening_address,0,sizeof(p->_listening_address));
				p->_listening_address.sin_addr.s_addr = NSSwapBigIntToHost(INADDR_ANY);
				p->_listening_address.sin_family = AF_INET;
				if (bind (p->_port_socket,
					(struct sockaddr*) &(p->_listening_address),
					sizeof (p->_listening_address)) == 0) 
					{
					ok = YES;
					break;
			}	}	}

		if (ok == NO) 
			{
			[p release];
			[NSException raise: NSInternalInconsistencyException
			format: @"[TcpInPort +newForReceivingFromPortNumber:] bind(): %s",
			strerror(errno)];
		}	}

				// If the caller didn't specify a port number, it was chosen 
				// for us.  Here, find out what number was chosen.
	if (!n)
		{									// FIX ME do this unconditionally?
		int size = sizeof (p->_listening_address);

		if (getsockname (p->_port_socket,
			 (struct sockaddr*)&(p->_listening_address), &size) < 0)
			{
			[p release];
			[NSException raise: NSInternalInconsistencyException format: 
			@"[TcpInPort +newForReceivingFromPortNumber:] getsockname(): %s",
			strerror(errno)];
			}
		NSAssert(p->_listening_address.sin_port, NSInternalInconsistencyException);
		n = NSSwapHostShortToBig(p->_listening_address.sin_port);
		}
			// Change _LISTENING_ADDRESS to the specific network address of
			// this machine so that, when we encoded our _LISTENING_ADDRESS for 
			// a Distributed Objects connection to another machine, they get
			// our unique host address that can identify us across the network.
	if (gethostname (hostname, len) < 0)
		{
		[p release];
		[NSException raise: NSInternalInconsistencyException format: 
			@"[TcpInPort +newForReceivingFromPortNumber:] gethostname(): %s",
		strerror(errno)];
		}

	if ((first_dot = strchr (hostname, '.')))
		*first_dot = '\0';				// Terminate the name at the first dot

//	_res.retrans = 1;		// timeout
//	_res.retry = 1;			// retry

	if (!(hp = gethostbyname (hostname)))
		hp = gethostbyname ("localhost");

	if (hp == 0)
		{
		NSLog(@"Unable to get IP address of '%s' or of 'localhost'", hostname);
#ifndef HAVE_INET_ATON
		p->_listening_address.sin_addr.s_addr = inet_addr("127.0.0.1");
#else
		inet_aton("127.0.0.1", &p->_listening_address.sin_addr.s_addr);
#endif
		}
	else
		memcpy (&(p->_listening_address.sin_addr), hp->h_addr, hp->h_length);
	}
		// Set it up to accept connections, let 10 pending connections queue
		// FIX ME Make this "10" a class variable? 
	if (listen (p->_port_socket, 10) < 0)
		{
		[p release];
		[NSException raise: NSInternalInconsistencyException
		format: @"[TcpInPort +newForReceivingFromPortNumber:] listen(): %s",
			strerror(errno)];
		}						// Initialize the tables for matching socket's 
								// to out ports and packets.
	p->_client_sock_2_out_port = NSCreateMapTable(NSIntMapKeyCallBacks,
												  NSObjectMapValueCallBacks,0);
	p->_client_sock_2_packet = NSCreateMapTable (NSIntMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
	{							// Wrap a CFSocket around the service's socket
	CFOptionFlags fl = kCFSocketReadCallBack;
	CFSocketContext cx = { 1, p, NULL, NULL, NULL };

	p->_cfSocket = CFSocketCreateWithNative(NULL, p->_port_socket, fl, &_PortCallback, &cx);
	}
								// Record new port in TcpInPort's class table.
	NSMapInsert (port_number_2_port, UINT2PTR(n), p);

	return p;
}

+ (id) newForReceivingFromRegisteredName:(NSString*)name
{
	return [self newForReceivingFromRegisteredName: name fromPort: 0];
}

+ (id) newForReceivingFromRegisteredName:(NSString*)name
								fromPort:(int)portn
{
	TcpInPort *p = [self newForReceivingFromPortNumber: portn];

	if (p)
		[[NSPortNameServer defaultPortNameServer] registerPort:p forName:name];

	return p;
}

+ (id) newForReceiving
{
	return [self newForReceivingFromPortNumber: 0];
}

- (unsigned) numberOfConnectedOutPorts
{
	return NSCountMapTable (_client_sock_2_out_port);
}

- (struct sockaddr_in*) _listeningSockaddr
{
	NSAssert(_is_valid, NSInternalInconsistencyException);
	return &_listening_address;
}
	// Read some data from FD; if we read enough to complete a packet, return 
	// packet.  Otherwise, keep partially read packet in _CLIENT_SOCK_2_PACKET
- (id) _tryToGetPacketFromReadableFD:(int)fd_index
{
	if (fd_index == _port_socket)
		{								// This is a connection request on the 
		int rval;						// original listen()'ing socket
		volatile id op;
		struct sockaddr_in clientname;
		int size = sizeof (clientname);
		int new = accept (_port_socket, (struct sockaddr*)&clientname, &size);

		if (new < 0)
			{
			[NSException raise: NSInternalInconsistencyException
				format: @"[TcpInPort receivePacketWithTimeout:] accept(): %s",
				strerror(errno)];
			}
							// Code to ensure that new socket is non-blocking.
		if ((rval = fcntl(new, F_GETFL, 0)) >= 0) 
			{
			rval |= O_NONBLOCK;
			if (fcntl(new, F_SETFL, rval) < 0) 
				{
				close(new);
				[NSException raise: NSInternalInconsistencyException format: 
					@"[TcpInPort receivePacketWithTimeout:] fcntl(SET): %s",
					strerror(errno)];
			}	}
		else 
			{
			close(new);
			[NSException raise: NSInternalInconsistencyException
			format: @"[TcpInPort receivePacketWithTimeout:] fcntl(GET): %s",
				strerror(errno)];
			}

		op = [TcpOutPort _newWithAcceptedSocket: new 
						 peeraddr: &clientname
						 inPort: self];
		[self _addClientOutPort: op];
		if (debug_tcp_port)
			NSLog(@"%s: Accepted connection from\n %@.\n",
					object_get_class_name (self), [op description]);
		[op release];
		}
	else
		{					// Data has arrived on an already-connected socket.
		NSPortMessage *packet;
		int remaining;		// See if there is already a InPacket object 
							// waiting for more data from this socket.
		if (!(packet = NSMapGet (_client_sock_2_packet, INT2PTR(fd_index))))
			{
			int packet_size;	// This is the beginning of a new packet on 
			id send_port;		// this socket.  Create a new InPacket object
			id receive_port;	// for gathering the data.

								// First, get the packet size and reply port, 
								// (which is encoded in the first few bytes of 
								// the stream).
			[NSPortMessage _getPacketSize: &packet_size
						   andSendPort: &send_port
						   andReceivePort: &receive_port
						   fromSocket: fd_index];
								// If we got an EOF when trying to read the 
								// packet prefix, invalidate the port, and keep 
								// on waiting for incoming data on other 
								// sockets.
			if (packet_size == EOF)
				{
				[(id)NSMapGet(_client_sock_2_out_port,INT2PTR(fd_index)) invalidate];

				return nil;
				}
			else
				{
				packet = [NSPortMessage _portMessageWithSendPort: receive_port
										receivePort: send_port
										capacity: packet_size];
				if (packet == nil)
					[NSException raise: NSInternalInconsistencyException
						format: @"[TcpInPort _tryToGetPacketFromReadableFD:"
						@" - failed to create incoming packet"];
				NSMapInsert(_client_sock_2_packet, INT2PTR(fd_index), packet);
				}
					// The packet has now been created with correct capacity
			}
							// Suck bytes from the socket into the packet; find 
							// out how many more bytes are needed before packet 
							// will be complete.
	remaining = [packet _fillFromSocket: (int)fd_index];
	if (remaining == EOF)	// We got an EOF when trying to read packet data;
		{					// release packet and invalidate the corresponding
							// port, and keep on waiting for incoming data on
							// other sockets.
		NSMapRemove(_client_sock_2_packet, INT2PTR(fd_index));
		[packet release];
		[(id) NSMapGet (_client_sock_2_out_port, INT2PTR(fd_index)) invalidate];

		return nil;
		}
	else 
		if (remaining == 0)		// No bytes are remaining to be read for this 
			{					// packet; the packet is complete; return it.
			NSAssert(packet &&[packet class],NSInternalInconsistencyException);
			NSMapRemove(_client_sock_2_packet, INT2PTR(fd_index));
			if (debug_tcp_port > 1)
				NSLog(@"%s: Read from socket %d\n",
						object_get_class_name(self), fd_index);

			return packet;
			}
		}

	return nil;
}
								// NSRunLoop will send this message just before 
- (void) getFds:(int*)fds 		// it's about to call select().  It is asking
		  count:(int*)count		// us to fill fds[] in with the sockets on
{								// which it should listen. *count should be set
	NSMapEnumerator me;			// to the number of sockets we put in the array
	long sock;
	id out_port;							// Make sure there is enough room
											// in the provided array.
	NSAssert(*count > NSCountMapTable (_client_sock_2_out_port), 	
				NSInternalInconsistencyException);

	*count = 0;									// Put in our listening socket.
	fds[(*count)++] = _port_socket;
						// Enumerate all our client sockets, and put them in.
	me = NSEnumerateMapTable (_client_sock_2_out_port);
	while (NSNextMapEnumeratorPair (&me, (void*)&sock, (void*)&out_port))
		fds[(*count)++] = sock;
}

- (void) _receivedEvent:(void*)data						// called by NSRunLoop 
				   type:(CFSocketCallBackType)type		// when select() says
				   extra:(const void*)extra				// the fd is ready
				   forMode:(NSString*)mode				// for reading.
{
	id arp = [NSAutoreleasePool new];
	id packet;

	NSAssert(type == kCFSocketAcceptCallBack, NSInvalidArgumentException);

	if ((packet = [self _tryToGetPacketFromReadableFD: PTR2INT(extra)]))
		[_packet_invocation invokeWithObject: packet];

	[arp release];
}

- (void) setReceivedPacketInvocation:(id)invocation
{
	NSAssert(!_packet_invocation, NSInternalInconsistencyException);
	_packet_invocation = invocation;
}

- (void) _addClientOutPort:(id)p	// Add and remove out port's (client 
{									// sockets) from collection of connections 
	int s = [p _portSocket];		// we handle

	NSAssert(_is_valid, NSInternalInconsistencyException);
 									// Make sure it hasn't already been added.
	NSAssert(!NSMapGet (_client_sock_2_out_port, INT2PTR(s)),
			NSInternalInconsistencyException);
									// Add it, and put its socket in the set of 
									// file descriptors we poll.
	NSMapInsert (_client_sock_2_out_port, INT2PTR(s), p);
}

- (void) _connectedOutPortInvalidated:(id)p
{													// Called by an OutPort in 
	id packet;										// its -invalidate method.
	int s = [p _portSocket];

	NSAssert(_is_valid, NSInternalInconsistencyException);
	if (debug_tcp_port)
		NSLog(@"%s: Closed connection from\n %@\n",
				object_get_class_name (self), [p description]);
	
	if ((packet = NSMapGet (_client_sock_2_packet, INT2PTR(s))))
		{
		NSMapRemove (_client_sock_2_packet, INT2PTR(s));
		[packet release];
		}
	NSMapRemove (_client_sock_2_out_port, INT2PTR(s));
}

- (int) _portSocket					{ return _port_socket; }

- (int) portNumber
{
	return (int) NSSwapHostShortToBig (_listening_address.sin_port);
}

- (void) invalidate
{
	if (_is_valid)
		{
		NSMapEnumerator me = NSEnumerateMapTable (_client_sock_2_out_port);
		int count = NSCountMapTable (_client_sock_2_out_port);
		id out_port;
		int sock;
		id out_ports[count];
		int i;				// These are here, and not in -dealloc, to prevent 
							// +newForReceivingFromPortNumber: from returning 
							// invalid sockets.
		NSMapRemove (socket_2_port, INT2PTR(_port_socket));
		NSMapRemove (port_number_2_port,
					INT2PTR(NSSwapHostShortToBig(_listening_address.sin_port)));

		for(i=0;NSNextMapEnumeratorPair(&me,(void*)&sock,(void*)&out_port);i++)
			out_ports[i] = out_port;
		for (i = 0; i < count; i++)		  // This will call each time 
			[out_ports[i] invalidate];	  // [self _invalidateConnectedOutPort:

		NSAssert(!NSCountMapTable (_client_sock_2_out_port), 
					NSInternalInconsistencyException);

				// FIX ME Perhaps should delay this close() to keep another
				// port from getting it.  This may help Connection invalidation  
				// confusion.  However, then the process might run out of FD's 
				// if the close() was delayed too long.
		if (_port_socket > 0)
			{
#ifdef __WIN32__
			closesocket (_port_socket);
#else
			close (_port_socket);
#endif /* __WIN32__ */
			}			// This also posts NSPortDidBecomeInvalidNotification
		[super invalidate];
		}
}

- (void) dealloc
{
	[self invalidate];
	NSFreeMapTable (_client_sock_2_out_port);
	NSFreeMapTable (_client_sock_2_packet);
	[super dealloc];
}

- (id) description
{
	return [NSString stringWithFormat: @"%s%c0x%x port %hd socket %d",
						object_get_class_name (self),
						_is_valid ? ' ' : '-',
						self,
						NSSwapHostShortToBig(_listening_address.sin_port),
						_port_socket];
}

- (Class) classForPortCoder					{ return [TcpOutPort class]; }

- (void) encodeWithCoder:(id)aCoder
{
	NSAssert(_is_valid, NSInternalInconsistencyException);
						// We are actually encoding a "send right" (ala Mach), 
						// not a receive right.  These values must match those 
						// expected by [TcpOutPort +newWithCoder] 
						// Encode these at bytes, not as C-variables, because 
						// they are already in "network byte-order". 
	[aCoder encodeBytes: &_listening_address.sin_port
			count: sizeof (_listening_address.sin_port)
			withName: @"socket number"];
	[aCoder encodeBytes: &_listening_address.sin_addr.s_addr
			count: sizeof (_listening_address.sin_addr.s_addr)
			withName: @"inet address"];
}

+ (id) newWithCoder:(id)aCoder
{											// An InPort cannot be created by 
	[self shouldNotImplement: _cmd];		// decoding, only OutPort's.
	return nil;
}

@end /* TcpInPort */

/* ****************************************************************************

	TcpOutPort

	An object that represents a  connection to a remote host.  Although it is
	officially an "Out" Port, we actually receive data on the socket that is
	this object's `_port_socket' ivar; TcpInPort takes care of this.

** ***************************************************************************/

@implementation TcpOutPort

/* 
   If SOCK is 0, then SOCKADDR must be non-NULL.  It is the address of
   the socket on which the remote TcpInPort is listen()'ing.  Note
   that it is *not* the address of the TcpOutPort's
   getsockname(_port_socket,...), and it is not the address of the
   TcpOutPort's getpeername(_port_socket,...).

   SOCK can be either an already-created socket, or 0, in which case a 
   socket will be created.

   If SOCK is non-zero, and SOCKADDR is non-zero, then this is a request
   to set the _remote_in_port_address ivar of a pre-existing TcpOutPort
   instance.  In this case the IP argument must match the _polling_in_port
   of the instance.

   IP can be either an already-created InPort object, or nil.
*/

+ (id) newForSendingToSockaddr:(struct sockaddr_in*)sockaddr 
			withAcceptedSocket:(int)sock
				 pollingInPort:ip
{
	TcpOutPort *p;		// Determine if a port exists for this sockaddr; if so,
						// return it.  However, there is no need to do this
						// if SOCK already holds an accept()'ed socket---in 
	if (!sock)			// that case we should always create a new OutPort obj
		{
		NSMapEnumerator me = NSEnumerateMapTable (out_port_bag);
		void *k;

		NSAssert(sockaddr, NSInternalInconsistencyException);
		while (NSNextMapEnumeratorPair (&me, &k, (void**)&p))
			{
			// FIX ME Do I need to make sure connectedInPort is the same too?
			// FIX ME Come up with a way to do this with a hash key, not a list

			if ((sockaddr->sin_port == p->_remote_in_port_address.sin_port)
	     		 	&& (sockaddr->sin_addr.s_addr
		  			== p->_remote_in_port_address.sin_addr.s_addr))
							// Assume that sin_family is equal.  Using memcmp()
	    		{			// doesn't work because sin_zero's may differ.
	      		NSAssert(p->_is_valid, NSInternalInconsistencyException);
	      		return [p retain];
		}	}	}		// FIX ME When the AcceptedSocket-style OutPort gets 
						// its _remote_in_port_address set, we should make sure 
						// that there isn't already an OutPort with that addrss

						// See if there already exists a TcpOutPort object with 
						// ivar _port_socket equal to SOCK.  If there is, and 
						// if sockaddr is non-null, this call may be a request 
						// to set the TcpOutPort's _remote_in_port_address ivar
	if (sock && (p = NSMapGet(socket_2_port, INT2PTR(sock))))
		{
		NSAssert([p isKindOfClass: [TcpOutPort class]], 	
				 NSInternalInconsistencyException);

		if (sockaddr)
			{		// Make sure the address we're setting it to is non-zero.
			NSAssert(sockaddr->sin_port, NSInternalInconsistencyException);

							// See if _remote_in_port_address is already set 
			if (p->_remote_in_port_address.sin_family)
				{
				if ((p->_remote_in_port_address.sin_port != sockaddr->sin_port)
						|| (p->_remote_in_port_address.sin_addr.s_addr
						!= sockaddr->sin_addr.s_addr))
					{
					NSString *od = [p description];
	
					NSMapRemove (out_port_bag, (void*)p);
					memcpy (&(p->_remote_in_port_address), sockaddr,
							sizeof (p->_remote_in_port_address));
					NSMapInsert (out_port_bag, (void*)p, p);
					DBLog(@"Out port changed from %@ to %@\n", od, [p description]);
				}	}
			else
				{			// It wasn't set before; set it by copying it in.
				memcpy (&(p->_remote_in_port_address), sockaddr,
						sizeof (p->_remote_in_port_address));
				if (debug_tcp_port)
					NSLog(@"TcpOutPort setting remote address\n%@\n", 
							[self description]);
			}	}

		if (p)
			{
			NSAssert(p->_is_valid, NSInternalInconsistencyException);
			return [p retain];
			}
		}					// There isn't already an in port for this sockaddr 
							// or sock, so create a new port.
	p = [[self alloc] init];

	if (sock)										// Set its socket.
		p->_port_socket = sock;
	else
		{
		p->_port_socket = socket (AF_INET, SOCK_STREAM, 0);
		if (p->_port_socket < 0)
			{
			[p release];
			[NSException raise: NSInternalInconsistencyException
			format: @"[TcpInPort newForSendingToSockaddr:...] socket(): %s",
						strerror(errno)];
		}	}
							// Register which InPort object will listen to 
							// replies from our messages.  This may be nil, in 
							// which case it can get set later in -sendPacket..
	p->_polling_in_port = ip;

	if (sockaddr)									// Set the port's address.
		{
		NSAssert(sockaddr->sin_port, NSInternalInconsistencyException);
		memcpy (&(p->_remote_in_port_address), sockaddr, sizeof(*sockaddr));
		}					// Else, _remote_in_port_address will remain as 
	else					// zero's for the time being, and may get set 
		{					// later by calling +newForSendingToSockaddr..  
							// with a non-zero socket, and a non-NULL sockaddr.
		memset (&(p->_remote_in_port_address), '\0', sizeof(*sockaddr));
		}
							// FIX ME Do I need to bind(_port_socket) to this 
							// address?  I don't think so.

	if (!sock) 						// Connect the socket to its destination,  
		{							// (if it hasn't been done already by a 
		int rval;					// previous accept() call.

		NSAssert(p->_remote_in_port_address.sin_family, 
					NSInternalInconsistencyException);

		if (connect (p->_port_socket,
			(struct sockaddr*)&(p->_remote_in_port_address), 
			sizeof(p->_remote_in_port_address)) < 0)
			{
			[p release];
			[NSException raise: NSInternalInconsistencyException
			format: @"[TcpInPort newForSendingToSockaddr:...] connect(): %s",
					strerror(errno)];
			}
										// Ensure the socket is non-blocking.
		if ((rval = fcntl(p->_port_socket, F_GETFL, 0)) >= 0) 
			{
			rval |= O_NONBLOCK;
			if (fcntl(p->_port_socket, F_SETFL, rval) < 0) 
				{
				[p release];
				[NSException raise: NSInternalInconsistencyException format: 
					@"[TcpInPort newForSendingToSockaddr:...] fcntl(SET): %s",
						strerror(errno)];
			}	}
		else 
			{
			[p release];
			[NSException raise: NSInternalInconsistencyException
			format: @"[TcpInPort newForSendingToSockaddr:...] fcntl(GET): %s",
						strerror(errno)];
		}	}
								// Put it in the shared socket->port map table.
	NSAssert(!NSMapGet (socket_2_port, (void*)p->_port_socket), 	
	NSInternalInconsistencyException);
	NSMapInsert (socket_2_port, INT2PTR(p->_port_socket), p);
											// Put it in TcpOutPort's registry.
	NSMapInsert (out_port_bag, (void*)p, (void*)p);

	{							// Wrap a CFSocket around the service's socket
	CFOptionFlags fl = kCFSocketWriteCallBack;
	CFSocketContext cx = { 0, p, NULL, NULL, NULL };

	p->_cfSocket = CFSocketCreateWithNative(NULL, p->_port_socket, fl, &_PortCallback, &cx);
	}

	return p;
}

+ (id) newForSendingToRegisteredName:(NSString*)name onHost:(NSString*)hostname
{
	return [[[NSPortNameServer defaultPortNameServer] portForName:name 
												 	  onHost:hostname] retain];
}

+ (id) _newWithAcceptedSocket:(int)s 
					 peeraddr:(struct sockaddr_in*)peeraddr
					 inPort:p
{
	return [self newForSendingToSockaddr: NULL
				 withAcceptedSocket: s
				 pollingInPort: p];
}

- (struct sockaddr_in*) _remoteInPortSockaddr
{
	return &_remote_in_port_address;
}

- (BOOL) sendPacket:packet timeout:(NSTimeInterval)timeout
{
	id reply_port = [packet replyInPort];

	NSAssert(_is_valid, NSInternalInconsistencyException);
				// If the socket of this TcpOutPort isn't already being polled
				// for incoming data by a TcpInPort, and if the packet's 
				// REPLY_PORT is non-nil, then set up this TcpOutPort's socket 
				// to be polled by the REPLY_PORT.  Once a TcpOutPort is 
				// associated with a particular TcpInPort, it is permanantly 
				// associated with that InPort; it cannot be re-associated with 
				// another TcpInPort later. The creation and use of TcpInStream 
				// objects could avoid this restriction; see the note about 
				// them at the top of this file.
	if (_polling_in_port == nil && reply_port != nil)
		{
		_polling_in_port = reply_port;
		[_polling_in_port _addClientOutPort: self];
		}
	else 
		if (_polling_in_port != reply_port)
		 [self error:"Instances of %s can't change their reply port once set.",
						object_get_class_name (self)];
			// Creating TcpInStream objects, and separating them from 
			// TcpOutPort's would fix this restriction.  However, it would
			// also have the disadvantage of using all socket's only for
			// sending data one-way, and creating twice as many socket's for
			// two-way exchanges.

			// Ask the packet to write it's bytes to the socket. The TcpPacket 
			// will also write a prefix, indicating the packet size and the 
			// port addresses.  If REPLY_PORT is nil, the third argument to 
			// this call will be NULL, and __writeToSocket: withSendPort: 
			// withReceivePort:timeout: will know that there is no reply port. 
	[packet _writeToSocket: _port_socket 
			withSendPort: self
			withReceivePort: reply_port
			timeout: timeout];

	return YES;
}

- (int) portNumber
{
	return (int) NSSwapHostShortToBig (_remote_in_port_address.sin_port);
}

- (int) _portSocket					{ return _port_socket; }
- (void) close						{ [self invalidate]; }

- (void) invalidate
{
	if (_is_valid)
		{
		id port = _polling_in_port;

		[self retain];
		_polling_in_port = nil;
					// This is here, and not in -dealloc, because invalidated
					// but not dealloc'ed ports should not be returned from
					// the out_port_bag in +newForSendingToSockaddr:...
		NSMapRemove (out_port_bag, (void*)self);
					// This is here, and not in -dealloc, because invalidated
					// but not dealloc'ed ports should not be returned from
					// the socket_2_port in +newForSendingToSockaddr:...
		NSMapRemove (socket_2_port, INT2PTR(_port_socket));

		[port _connectedOutPortInvalidated: self];
					// This also posts a NSPortDidBecomeInvalidNotification.
		[super invalidate];
					// FIX MEDelay this close() to keep another port from
					// getting it?  May help Connection invalidation confusion.
		if (_port_socket > 0)
			{
#ifdef	__WIN32__
			if (closesocket (_port_socket) < 0)
#else
			if (close (_port_socket) < 0)
#endif /* __WIN32 */
				{
				[NSException raise: NSInternalInconsistencyException
					format: @"[TcpOutPort -invalidate:] close(): %s",
					strerror(errno)];
			}	}
		[self release];
		}
}

- (void) dealloc
{
	[self invalidate];
	[super dealloc];
}									// Make sure Connection's always send us 
									// bycopy. as own class, not a Proxy class
- (id) classForPortCoder					{ return [self class]; }

- (id) description
{
	return [NSString stringWithFormat: @"%s%c0x%x host %s port %d socket %d",
					 object_get_class_name (self),
					 _is_valid ? ' ' : '-',
					 self,
					 inet_ntoa (_remote_in_port_address.sin_addr),
					 NSSwapHostShortToBig(_remote_in_port_address.sin_port),
					 _port_socket];
}

- (void) encodeWithCoder:(id)aCoder
{
	NSAssert(_is_valid, NSInternalInconsistencyException);
	NSAssert(!_polling_in_port
		|| (NSSwapHostShortToBig(_remote_in_port_address.sin_port)
		!= [_polling_in_port portNumber]), NSInternalInconsistencyException);
						// Encode these at bytes, not as C-variables, because
						// they are already in "network byte-order".
	[aCoder encodeBytes: &_remote_in_port_address.sin_port
		count: sizeof (_remote_in_port_address.sin_port)
		withName: @"socket number"];
	[aCoder encodeBytes: &_remote_in_port_address.sin_addr.s_addr
		count: sizeof (_remote_in_port_address.sin_addr.s_addr)
		withName: @"inet address"];
	if (debug_tcp_port)
		NSLog(@"TcpOutPort encoded port %hd host %s\n",
			NSSwapHostShortToBig(_remote_in_port_address.sin_port),
			inet_ntoa (_remote_in_port_address.sin_addr));
}

+ (id) newWithCoder:(id)aCoder
{
	struct sockaddr_in addr;

	addr.sin_family = AF_INET;
	[aCoder decodeBytes: &addr.sin_port
			count: sizeof (addr.sin_port)
			withName: NULL];
	[aCoder decodeBytes: &addr.sin_addr.s_addr
			count: sizeof (addr.sin_addr.s_addr)
			withName: NULL];
	if (debug_tcp_port)
		NSLog(@"TcpOutPort decoded port %hd host %s\n",
				NSSwapHostShortToBig(addr.sin_port), inet_ntoa (addr.sin_addr));

	return [TcpOutPort newForSendingToSockaddr: &addr
					   withAcceptedSocket: 0
					   pollingInPort: nil];
}

@end /* TcpOutPort */

/* ****************************************************************************

	NSMessagePort

	Local messaging port.  FIX ME implement with UNIX domain socket.  Allows
	passing open descriptors (sendmsg/recvmsg) for privilege manipulation etc.

** ***************************************************************************/

@implementation NSMessagePort			// local comm only
@end

/* ****************************************************************************

	NSSocketPort

** ***************************************************************************/

//@implementation NSSocketPort			// BSD sockets
//@end
