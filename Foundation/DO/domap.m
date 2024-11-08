/*
   domap.m

   Local host Distributed Objects name server

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:	July 2018

   ==========================================================================
   derived from Apple's MiniSOAP example (Apple BSD type license)
   MiniSOAP example is Copyright (C) 2009 Apple Inc. All Rights Reserved.
   ==========================================================================
   derived from gdomap.c (LGPL)
   Copyright (C) 1996, 1997, 1998 Free Software Foundation, Inc.
   Author: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   ==========================================================================

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#import <Foundation/Foundation.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFStream.h>

#include <unistd.h>
#include <signal.h>
#include <fcntl.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>		// ntohs()

#include "domap.h"


typedef enum {
    kTCPServerCouldNotBindToIPv4Address = 1,
    kTCPServerCouldNotBindToIPv6Address = 2,
    kTCPServerNoSocketsAvailable        = 3,
} TCPServerErrorCode;

typedef struct {
	const char *name;					// Service name registered
	unsigned int port;					// Port it was mapped to
	unsigned short size;				// Number of bytes in name
	unsigned char net;					// Type of port registered
	unsigned char svc;					// Type of port registered
} map_entry;


NSString * const TCPServerErrorDomain = @"TCPServerErrorDomain";

static int __debug = 2;


@interface TCPServer : NSObject
{
    uint16_t port;
    CFSocketRef ipv4socket;
}

- (uint16_t) port;
- (void) setPort:(uint16_t)value;

- (BOOL) start:(NSError **)error;
- (BOOL) stop;
										// new connection established
- (void) handleNewConnectionFromAddress:(NSData *)addr
							inputStream:(NSInputStream *)is
							outputStream:(NSOutputStream *)os;
@end


@interface DOMapServer : TCPServer
{
	NSMapTable *_port_2_name;
	NSMapTable *_name_2_service;
}

- (void) registerService:(map_entry *)item;
- (void) unregisterService:(map_entry *)item;
- (void) unregisterDOPort:(uint16_t)value;
- (void) unregisterOnlyDOPort:(uint16_t)value;

- (map_entry *) lookupName:(const char *)name;

@end

							// class represents each incoming client connection
@interface TCPConnection : NSObject  <NSStreamDelegate>
{
    NSData *peerAddress;
    TCPServer *server;
    NSInputStream *istream;
    NSOutputStream *ostream;
    NSMutableData *ibuffer;
    NSMutableData *obuffer;
    BOOL isValid;
    BOOL firstResponseDone;
}

- (id) initWithPeerAddress:(NSData *)addr
			   inputStream:(NSInputStream *)istr
			   outputStream:(NSOutputStream *)ostr
			   forServer:(TCPServer *)serv;

- (NSData *) peerAddress;

- (TCPServer *) server;

- (void) invalidate;						// shut down the connection
- (BOOL) isValid;

@end


static void						// called when a new connection is established
_TCPServerAcceptCallBack( CFSocketRef socket,
						  CFSocketCallBackType type,
						  CFDataRef address,
						  const void *data,
						  void *info)
{
    TCPServer *server = (TCPServer *)info;
											// AcceptCallBack's data parameter
    if (kCFSocketAcceptCallBack == type)	// is a ptr to a CFSocketNativeHandle
		{
		CFSocketNativeHandle h = *(CFSocketNativeHandle *)data;
        NSData *peer = nil;
		struct sockaddr_in sa;
		unsigned int size = sizeof(sa);
        CFReadStreamRef readStream = NULL;
		CFWriteStreamRef writeStream = NULL;

        if (getpeername(h, &sa, &size) == 0)
			{
			if (strcmp("127.0.0.1", inet_ntoa(sa.sin_addr)) != 0)
				NSLog(@"reject non-loopback access from %s (%d)\n",
						inet_ntoa(sa.sin_addr), ntohs(sa.sin_port));
			else
				{
				NSLog(@"accept handle %d from %s (%d)\n", h,
						inet_ntoa(sa.sin_addr), ntohs(sa.sin_port));
            	peer = [NSData dataWithBytes:&sa length:size];
			}	}
		else
			NSLog(@"Error getting peer name %s", strerror(errno));

		if (!peer)
			close(h), h = -1;
        CFStreamCreatePairWithSocket(NULL, h, &readStream, &writeStream);

        if (readStream && writeStream)
			{
			CFStringRef k = kCFStreamPropertyShouldCloseNativeSocket;
			int v = 1;				// s/b kCFBooleanTrue a CFNumber constant
 
			CFReadStreamSetProperty(readStream, k, &v);
            CFWriteStreamSetProperty(writeStream, k, &v);

            [server handleNewConnectionFromAddress:peer
					inputStream:(NSInputStream *)readStream
					outputStream:(NSOutputStream *)writeStream];
			}
		else
            close(h);					// close native handle if any failures

		[(NSInputStream *)readStream release];
		[(NSOutputStream *)writeStream release];
		}
}


@implementation DOMapServer

- (id) init
{
	_name_2_service = NSCreateMapTable( NSNonOwnedCStringMapKeyCallBacks,
										NSOwnedPointerMapValueCallBacks, 0);
	_port_2_name = NSCreateMapTable( NSIntMapKeyCallBacks,
									 NSNonOwnedPointerMapValueCallBacks, 0);
	return self;
}

- (void) registerService:(map_entry *)item
{
	NSMapInsertIfAbsent(_name_2_service, item->name, item);
	NSMapInsert(_port_2_name, INT2PTR(item->port), item->name);
}

- (void) unregisterService:(map_entry *)item
{
	NSMapRemove(_port_2_name, INT2PTR(item->port));
	NSMapRemove(_name_2_service, item->name);
}

- (void) unregisterDOPort:(uint16_t)dop
{
	const char *name = NSMapGet(_port_2_name, INT2PTR(dop));

	NSMapRemove(_port_2_name, INT2PTR(dop));
	if (name)
		NSMapRemove(_name_2_service, name);
}

- (void) unregisterOnlyDOPort:(uint16_t)dop
{
	NSMapRemove(_port_2_name, INT2PTR(dop));
}

- (map_entry *) lookupName:(const char *)name
{
	return NSMapGet(_name_2_service, name);
}

- (void) dealloc
{
    [self stop];
	NSFreeMapTable (_port_2_name);
	NSFreeMapTable (_name_2_service);
    [super dealloc];
}

@end


@implementation TCPServer

- (void) handleNewConnectionFromAddress:(NSData *)addr
							inputStream:(NSInputStream *)is
							outputStream:(NSOutputStream *)os
{
	[[TCPConnection alloc] initWithPeerAddress:addr
						   inputStream:is
						   outputStream:os
						   forServer:self];
/*  The connection at this point is turned loose to exist on its own, and not
	released or autoreleased.  Alternatively, the TCPServer could keep a list
	of connections and TCPConnection would have to tell the server to delete
	one at invalidation time.  This would perhaps be more correct and ensure no
	spurious leaks get reported by the tools, but TCPServer has nothing further
	it wants to do with the TCPConnections and would just be "owning" the
	connections for form. */
}

- (void) setPort:(uint16_t)value		{ port = value; }
- (uint16_t) port						{ return port; }

- (BOOL) handle:(NSError **)error withCode:(TCPServerErrorCode)code
{
	if (error)
		*error = [[NSError alloc] initWithDomain:TCPServerErrorDomain
								  code:code
								  userInfo:nil];
	if (ipv4socket)
		CFRelease(ipv4socket), ipv4socket = NULL;

	return NO;
}

- (BOOL) start:(NSError **)error
{
    CFSocketContext sx = {1, self, NULL, NULL, NULL};

    ipv4socket = CFSocketCreate(NULL, PF_INET, SOCK_STREAM, IPPROTO_TCP,
		kCFSocketAcceptCallBack, &_TCPServerAcceptCallBack, &sx);

    if (ipv4socket == NULL)
		return [self handle:error withCode:kTCPServerNoSocketsAvailable];

    int yes = 1;
    setsockopt(CFSocketGetNative(ipv4socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));

    // set up IPv4 endpoint, if port is 0 the kernel to choose a port for us
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
//    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(port);
    addr4.sin_addr.s_addr = htonl(INADDR_ANY);
    NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];

    if (kCFSocketSuccess != CFSocketSetAddress(ipv4socket, (CFDataRef)address4))
		return [self handle:error withCode:kTCPServerCouldNotBindToIPv4Address];
	
    if (port == 0)				// bind success
		{
        NSData *addr = [(NSData *)CFSocketCopyAddress(ipv4socket) autorelease];

        memcpy(&addr4, [addr bytes], [addr length]);
        port = ntohs(addr4.sin_port);
    	}
								// set up the run loop sources for the sockets
    CFRunLoopRef rl = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source4 = CFSocketCreateRunLoopSource(NULL, ipv4socket, 0);
    CFRunLoopAddSource(rl, source4, kCFRunLoopCommonModes);
    CFRelease(source4);

	signal(SIGPIPE, SIG_IGN);	// do not interupt if we write to the dead

    return YES;
}
								// NSRunLoop will send this message just before
- (void) getFds:(int*)fds 		// it's about to call select().  It is asking
		  count:(int*)count		// us to fill fds[] in with the sockets on
{								// which it should listen. *count should be set
	*count = 0;					// to the number of sockets we put in the array
	fds[(*count)++] = CFSocketGetNative(ipv4socket);	// our listening socket
}

- (BOOL) stop
{
    CFSocketInvalidate(ipv4socket);
    CFRelease(ipv4socket), ipv4socket = NULL;

    return YES;
}

@end

/* ****************************************************************************

	DO map registration

** ***************************************************************************/

static map_entry *
DOLookup(DOMapServer *sv, int port, const char *buf, unsigned char ptype)
{
	map_entry *m = (map_entry *)[sv lookupName:buf];

	if (m != 0 && (m->net | m->svc) != ptype)
		{
		if (__debug > 1)
			fprintf(stderr, "requested service is of wrong type\n");
		m = 0;	/* Name exists but is of wrong type.	*/
		}

	if (m)						// check to see if we can bind to the old port,
		{						// and if we can we assume that the process has
		int	sock = -1;			// gone away and remove it from the map.

		if ((ptype & GDO_NET_MASK) == GDO_NET_TCP)
			sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
		else if ((ptype & GDO_NET_MASK) == GDO_NET_UDP)
			sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

		if (sock < 0)
			perror("unable to create new socket");
		else
			{
			int	r = 1;

			if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char*)&r, sizeof(r)) < 0)
				perror("unable to set socket options");
			else
				{
				struct sockaddr_in sa;
				int result;
				unsigned short p = (unsigned short)m->port;

				memset(&sa, '\0', sizeof(sa));
				sa.sin_family = AF_INET;
				sa.sin_addr.s_addr = htonl(INADDR_ANY);
				sa.sin_port = htons(p);
				result = bind(sock, (void*)&sa, sizeof(sa));

				if (result == 0)
					{
					if (__debug > 1)
						fprintf(stderr, "removing stale registration of port %d for %s\n", m->port, m->name);
					[sv unregisterService:m];
					m = 0;
					}
				}
			close(sock);
			}
		}

	if (m)									// found live server
		{
		if (__debug > 1)
			fprintf(stderr, "service %s found with port %d\n", m->name, m->port);

		return m;
		}

	if (__debug > 1)
		fprintf(stderr, "requested service not found\n");

	return 0;
}

static void
DOUnregister(DOMapServer *sv, int port, const char *buf, int size, unsigned char ptype)
{
	if (port == 0 || size > 0)
		{
		map_entry *m = (map_entry *)[sv lookupName:buf];

		if (m)
			{
			if ((m->net | m->svc) != ptype)
				{
				if (__debug)
					fprintf(stderr, "Attempted unregister with wrong type\n");
				}
			else
				[sv unregisterService:m];
			}
		else
			{
			if (__debug > 1)
			  	fprintf(stderr, "requested service not found\n");
			}
		}
	else
		[sv unregisterDOPort:port];
}

static BOOL
DORegister(DOMapServer *sv, const char *buf, unsigned int len, unsigned int port, unsigned char ptype)
{
	map_entry *m = (map_entry *)[sv lookupName:buf];

	if (m != 0 && port == m->port)		// Special case - we already have this
		return YES;						// name registered for this port

	if (m != 0)
		{
		int	sock = -1;

		if ((ptype & GDO_NET_MASK) == GDO_NET_TCP)
			sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
		else if ((ptype & GDO_NET_MASK) == GDO_NET_UDP)
			sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

		if (sock < 0)
			perror("unable to create new socket");
		else
			{
			int	r = 1;

			if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char*)&r, sizeof(r)) < 0)
				perror("unable to set socket options");
			else
				{
				struct sockaddr_in sa;
				int result;
				short p = m->port;

				memset(&sa, '\0', sizeof(sa));
				sa.sin_family = AF_INET;
				sa.sin_addr.s_addr = htonl(INADDR_ANY);
				sa.sin_port = htons(p);
				result = bind(sock, (void*)&sa, sizeof(sa));

				if (result == 0)
					{
					if (__debug > 1)
						fprintf(stderr, "re-register %s from port %d to %lu\n", m->name, m->port, port);
					[sv unregisterOnlyDOPort:m->port];
					m->port = port;
					m->net = (ptype & GDO_NET_MASK);
					m->svc = (ptype & GDO_SVC_MASK);
					[sv registerService: m];

					return YES;
					}
				}
			close(sock);
			}
		}
	else if (port == 0)
		fprintf(stderr, "port not provided in request\n");
	else
		{
		m = (map_entry*)malloc(sizeof(map_entry) + len + 1);

		memset(m, '\0', (sizeof(map_entry) + len + 1));
		m->port = port;
///		m->name = calloc(1, len+1);
		m->name = (char *)m + sizeof(map_entry);
		m->size = len;
		m->net = (ptype & GDO_NET_MASK);
		m->svc = (ptype & GDO_SVC_MASK);
		memcpy((char *)m->name, buf, len);

		[sv registerService: m];
		if (__debug > 1)
			fprintf(stderr, "registered %d to %s\n", m->port, m->name);

		return YES;
		}

	return NO;
}


@implementation TCPConnection

- (id) initWithPeerAddress:(NSData *)addr
			   inputStream:(NSInputStream *)is
			   outputStream:(NSOutputStream *)os
			   forServer:(TCPServer *)sv
{
	NSRunLoop *rl = [NSRunLoop currentRunLoop];

    peerAddress = [addr copy];
    server = sv;
    istream = [is retain];
    ostream = [os retain];
    [istream setDelegate:self];
    [ostream setDelegate:self];
    [istream scheduleInRunLoop:rl forMode:(id)kCFRunLoopCommonModes];
    [ostream scheduleInRunLoop:rl forMode:(id)kCFRunLoopCommonModes];
    [istream open];
    [ostream open];
    isValid = YES;

    return self;
}

- (void) dealloc
{
    [self invalidate];
    [peerAddress release];
    [super dealloc];
}

- (NSData *) peerAddress				{ return peerAddress; }
- (TCPServer *) server					{ return server; }

- (BOOL) isValid						{ return isValid; }

- (void) invalidate
{
    if (isValid)
		{
        isValid = NO;
        [istream close];
        [ostream close];
        [istream release],		istream = nil;
        [ostream release],		ostream = nil;
        [ibuffer release],		ibuffer = nil;
        [obuffer release],		obuffer = nil;
        [self release];		// removes the implicit retain the TCPConnection
		}					// has on itself given to it by the TCPServer
}							// when it abandoned the new connection.

/* ****************************************************************************

	processIncomingBytes

	YES return means that a complete request was parsed and the caller should
	call again as the buffered bytes may have another complete request available

** ***************************************************************************/

- (BOOL) processIncomingBytes
{
	map_entry *m;
	const do_req *rq;
	unsigned char ptype = 0;
	unsigned long port;
	unsigned const char *buf;
	unsigned char wbuf[8] = {0};				// default return value is a
												// four byte number set to zero
	NSLog(@"processIncomingBytes");
//	NSLog(@"%s", [ibuffer bytes]);

	if ([ibuffer length] != DO_REQ_SIZE)
		{
		NSLog(@"Invalid length request %d", [ibuffer length]);
		return NO;
		}

	rq = [ibuffer bytes];
	if (rq->ptype != GDO_TCP_GDO && rq->ptype != GDO_TCP_FOREIGN)
		NSLog(@"Invalid port type in request\n");
	else
		ptype = rq->ptype;

	port = ntohl(rq->port);
	buf = rq->name;

	switch (rq->rtype)
		{
		case GDO_REGISTER:
			NSLog(@"Register port %d with name %s\n", port, buf);
			if (DORegister((DOMapServer *)server, buf, strlen(buf), port, ptype))
				*(unsigned long*)wbuf = htonl(port);
			break;

		case GDO_UNREG:
			NSLog(@"Unregister port %d with name %s\n", port, buf);
			DOUnregister((DOMapServer *)server, port, buf, strlen(buf), ptype);
			break;

		case GDO_LOOKUP:
			NSLog(@"Lookup port %d with name %s\n", port, buf);
			if ((m = DOLookup((DOMapServer *)server, port, buf, ptype)))
				*(unsigned long*)wbuf = htonl(m->port);
		default:
			break;
		}

	if (!obuffer)
		obuffer = [[NSMutableData alloc] init];
	[obuffer appendBytes:wbuf length:4];		// prep response to client

	return NO;
}

/* ****************************************************************************

	processOutgoingBytes -- Write as many bytes as possible from buffer

** ***************************************************************************/

- (void) processOutgoingBytes
{
    unsigned olen;

//	NSLog(@"Server processOutgoingBytes");

    if (![ostream hasSpaceAvailable])
        return;

    if ((olen = [obuffer length]) > 0)
		{
        int writ = [ostream write:[obuffer bytes] maxLength:olen];

        if (writ < olen)	// buffer any unwritten bytes for later writing
			{
            memmove([obuffer mutableBytes], [obuffer mutableBytes] + writ, olen - writ);
            [obuffer setLength:olen - writ];
            return;
        	}
        [obuffer setLength:0];
	NSLog(@"Connection close output stream");
		[self invalidate];
    	}
}

- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent
{
	switch (streamEvent)
		{
		case NSStreamEventHasBytesAvailable:
			{
			uint8_t buf[2 * 1024];
			uint8_t *buffer = NULL;
			NSInteger len = 0;

			if (![istream getBuffer:&buffer length:&len])
				{
				int amount = [istream read:buf maxLength:sizeof(buf)];

				buffer = buf;
				len = amount;
				}
			if (len > 0)
				{
				if (!ibuffer)
					ibuffer = [[NSMutableData alloc] init];
				[ibuffer appendBytes:buffer length:len];
				do {} while ([self processIncomingBytes]);
				}
			}
			break;

		case NSStreamEventHasSpaceAvailable:
			[self processOutgoingBytes];
			break;

		case NSStreamEventEndEncountered:
			[self processIncomingBytes];
			if (stream == ostream)		// When the output stream is closed
				[self invalidate];		// no further writing will succeed and
			break;						// will terminate the processing of any
										// pending requests with incoming bytes
		case NSStreamEventErrorOccurred:
			NSLog(@"TCPServer stream error: %@", [stream streamError]);
			[self invalidate];
		default:
			break;
		}
}

@end


void
usage(char *err_msg, int exit_status)
{
	if (exit_status)
		fprintf(stdout, "\nInvalid options, %s.\nUsage:\n\n", err_msg);
	else
		fprintf(stdout, "\n%s\n\n", err_msg);

	fprintf(stdout, " domap [-l] <listen port>   # listen on alternate port\n");
	fprintf(stdout, " domap [-d]                 # debug, do not fork\n");
	fprintf(stdout, "\n");

	exit(exit_status);
}

void
run_server(int port)
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	DOMapServer *ds = [[DOMapServer alloc] init];
    NSError *error = nil;

    [ds setPort:(uint16_t)port];

    if (![ds start:&error])
        NSLog(@"Error starting server: %@", error);
    else
        NSLog(@"Starting server on port %d", port);

    [[NSRunLoop currentRunLoop] run];
    [ds release];

    [pool release];
}

void
fork_server(int port)
{
	int c;

	switch (fork())
		{
		case -1:	usage("domap - fork failed", 1);
		case 0:		break;							// child
		default:	exit(0);						// parent
		}

#ifdef	NeXT
	setpgrp(0, getpid());
#else
	setsid();
#endif
	for (c = 0; c < FD_SETSIZE; c++)	// close any open fd
		close(c);

	open("/dev/null", O_RDONLY);		// stdin
	open("/dev/null", O_WRONLY);		// stdout
	open("/dev/tty",  O_WRONLY);		// stderr

	run_server(port);
}

int
main(int argc, char **argv, char **env)
{
	extern char	*optarg;
	extern int optind;
	int c, debug = 0;
	int port = 538;

	while ((c = getopt(argc, argv, "vhdl")) != -1)
		switch (c)
			{
			case 'l':
				if (optind == argc)						// detect missing arg
					usage("missing port argument after option: -l", 1);
				port = atoi(optarg);		break;
			case 'd':	debug = 1;			break;		// do not fork
			case 'h':	usage("domap Distributed Objects name server help:", 0);
			case 'v':	usage("mGSTEP domap v0.3", 0);
			};

	if (optind > argc)
		usage("expected argument after options", 1);

    if (port < 1000 && getuid() != 0)
		usage("default port (538) requires launch with root privilege", 1);

	if (debug)
		run_server(port);
	else
		fork_server(port);

	exit(0);
}
