/*
   NSPortMessage.m

   Distributed Objects data container class.  Most of this code is
   from Andrew Kachites McCallum's original GNU DO implementation.

   Copyright (C) 2010 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	January 2010

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSPortMessage.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPort.h>

#include "Stream.h"

#include <netinet/in.h>							// for inet_ntoa()
#include <sys/socket.h>
#include <sys/select.h>

#define PREFIX_LENGTH_TYPE	 u32
#define PREFIX_LENGTH_SIZE	 sizeof (PREFIX_LENGTH_TYPE)
#define PREFIX_ADDRESS_TYPE  struct sockaddr_in
#define PREFIX_ADDRESS_SIZE  sizeof (PREFIX_ADDRESS_TYPE)
#define	PREFIX_SP_OFF		 PREFIX_LENGTH_SIZE
#define	PREFIX_RP_OFF		 (PREFIX_LENGTH_SIZE + PREFIX_ADDRESS_SIZE)
#define PREFIX_SIZE			 (PREFIX_LENGTH_SIZE + 2*PREFIX_ADDRESS_SIZE)


@interface TcpInPacket : InPacket			// In and Out Packet classes
											// Holders of sent & received data
- (int) _fillFromSocket:(int)s;

@end


@interface TcpOutPacket : OutPacket	

- (void) _writeToSocket:(int)s 
		   withSendPort:(id)sp
		   withReceivePort:(id)rp
		   timeout:(NSTimeInterval)t;
@end


@implementation NSPortMessage				// FIX ME wrapper around old code

- (id) initWithSendPort:(NSPort *)sendPort
			receivePort:(NSPort *)receivePort
			components:(NSArray *)components
{
	return nil;
}

- (NSArray *) components				{ return nil; }

- (NSPort *) receivePort				{ return nil; }
- (NSPort *) sendPort					{ return nil; }

@end


@implementation NSPortMessage (mGSTEP)

+ (id) _portMessageWithSendPort:(NSPort *)sendPort
					receivePort:(NSPort *)receivePort
					capacity:(unsigned)capacity
{
	id pm;

	if (!receivePort)
		pm = [[TcpOutPacket alloc] initForSendingWithCapacity: capacity
								   replyInPort: sendPort];
	else
		pm = [[TcpInPacket alloc] initForReceivingWithCapacity: capacity
								  receivingInPort: receivePort
								  replyOutPort: sendPort];
	return pm;
}

@end


@implementation InPacket
													// designated initializer.
- (id) initForReceivingWithCapacity:(unsigned)c
					receivingInPort:ip
					replyOutPort:op
{
	if ((self = [super initWithCapacity: c prefix: 0]))
		{
		NSAssert([op isValid], NSInternalInconsistencyException);
		NSAssert(!ip || [ip isValid], NSInternalInconsistencyException);
		_reply_out_port = op;
		_receiving_in_port = ip;
		}

	return self;
}

- (id) replyOutPort						{ return _reply_out_port; }
- (id) receivingInPort					{ return _receiving_in_port; }

@end /* InPacket */


@implementation OutPacket
													// designated initializer.
- (id) initForSendingWithCapacity:(unsigned)c replyInPort:ip
{
	if ((self = [super initWithCapacity:c prefix:[[self class] prefixSize]]))
		{
		NSAssert([ip isValid], NSInternalInconsistencyException);
		_reply_in_port = ip;
		}

	return self;
}

+ (unsigned) prefixSize					{ return 0; }
- (id) replyInPort						{ return _reply_in_port; }

@end /* OutPacket */


static int
TryRead(int desc, int tim, unsigned char* dat, int len)
{
	struct timeval timeout;		// Attempt to write to a non blocking channel.
	fd_set fds;					// Time out in specified time.  If length of
	void *to;					// data is zero then just wait for descriptor
	int rval;					// to be readable.  If the length is negative
	int pos = 0;				// then attempt to read the absolute value of
	time_t when = 0;			// length but return as soon as anything is
	int neg = 0;				// read.  Return -1 on failure, -2 on timeout
								// Return number of bytes read
	if (len < 0) 
		{
		neg = 1;
		len = -len;
		}

	timeout.tv_sec = 0;			// First time round we do a select with an
	timeout.tv_usec = 0;		// instant timeout to see if the descriptor
								// is already writable.
	for (;;) 
		{
		to = &timeout;
		memset(&fds, '\0', sizeof(fds));
		FD_SET(desc, &fds);

		if ((rval = select(FD_SETSIZE, &fds, 0, 0, to)) == 0) 
			{
			time_t	now = time(0);
		
			if (when == 0) 
				when = now;
			else 
				if (now - when >= tim) 
					return(-2);								// Timed out.
				else 					// Set the timeout for a new call to
					{					// select next time round the loop.
					timeout.tv_sec = tim - (now - when);
					timeout.tv_usec = 0;
			}		}
		else 
			if (rval < 0) 
				return (-1);								// Error in select
			else 
				if (len > 0) 
					{
					if ((rval = read(desc, &dat[pos], len - pos)) < 0) 
						{
						if (errno != EWOULDBLOCK) 
							return(-1);						// Error in read
						}
					else 
						if (rval == 0) 
							return(-1);						// End of file.
						else 
							{
							pos += rval;
							if (pos == len || neg == 1) 
								return(pos);				// Read as needed.
					}		}
				else 
					return(0);					// Not actually asked to read
		}
}

static int
TryWrite(int desc, int tim, unsigned char* dat, int len)
{
	struct timeval timeout;		// Attempt to write to a non blocking channel.
	fd_set fds;					// Time out in specified time.  If length of
	void *to;					// data is zero then just wait for descriptor
	int rval;					// to be writable.  If the length is negative
	int pos = 0;				// then attempt to write the absolute value of
	time_t when = 0;			// length but return as soon as anything is
	int neg = 0;				// written. Return -1 on failure, -2 on timeout
								// Return number of bytes written.
	if (len < 0) 
		{
		neg = 1;
		len = -len;
		}

	timeout.tv_sec = 0;			// First time round we do a select with an
	timeout.tv_usec = 0;		// instant timeout to see if the descriptor
								// is already writable.
	for (;;) 
		{
		to = &timeout;
		memset(&fds, '\0', sizeof(fds));
		FD_SET(desc, &fds);

		if ((rval = select(FD_SETSIZE, 0, &fds, 0, to)) == 0) 
			{
			time_t	now = time(0);

			if (when == 0) 
				when = now;
			else 
				if (now - when >= tim) 
					return(-2);									// Timed out.
				else 					// Set the timeout for a new call to 
					{					// select next time round the loop.
					timeout.tv_sec = tim - (now - when);
					timeout.tv_usec = 0;
			}		}
		else 
			if (rval < 0) 
				return(-1);								// Error in select.
			else 
				if (len > 0) 
					{
					if ((rval = write(desc, &dat[pos], len - pos)) <= 0) 
						{
						if (errno != EWOULDBLOCK) 	
							return(-1);					// Error in write.	
						}
					else 
						{
						pos += rval;
						if (pos == len || neg == 1) 
							return(pos);				// Written as needed.
					}	}
				else 
      				return(0);					// Not actually asked to write.
		}
}

@implementation NSPortMessage (TcpInPacket)

+ (void) _getPacketSize:(int*)packet_size 
			andSendPort:(id*)sp
			andReceivePort:(id*)rp
			fromSocket:(int)s
{
	char prefix_buffer[PREFIX_SIZE];
	int c = TryRead (s, 3, prefix_buffer, PREFIX_SIZE);
  
	if (c <= 0)
		{
		*packet_size = EOF;
		*sp = nil;
		*rp = nil;

		return;
		}
			// Was: [self error: "Failed to get packet prefix from socket."];
	if (c != PREFIX_SIZE)		// FIX ME treating this the same as EOF, but
		{						// perhaps we should treat it differently.
		fprintf (stderr, "[%s %s]: Got %d chars instead of full prefix\n",
				class_get_class_name (self), sel_get_name (_cmd), c);
		*packet_size = EOF;
		*sp = nil;
		*rp = nil;

		return;
		}      				// *size is the number of bytes in the packet, not 
							// including the PREFIX_SIZE-byte header. */
	*packet_size = NSSwapBigIntToHost (*(PREFIX_LENGTH_TYPE*) prefix_buffer);
	NSAssert(packet_size, NSInternalInconsistencyException);

			// If the reply address is non-zero, and the TcpOutPort for this 
			// socket doesn't already have its _address ivar set, set it now.
	{
    struct sockaddr_in addr;		// Use memcpy instead of simply casting the 
									// pointer because some systems fail to do 
									// the cast correctly (alignment issues?)

								// Get the senders send port (our receive port)
    memcpy (&addr, prefix_buffer + PREFIX_SP_OFF, sizeof (typeof (addr)));
    if (addr.sin_family)
		{
		u16 pnum = NSSwapHostShortToBig(addr.sin_port);

        *sp = [NSPort _newForReceivingFromPortNumber: pnum];
		[(*sp) autorelease];
		}
    else
		*sp = nil;
							// Now get the senders receive port (our send port)
	memcpy (&addr, prefix_buffer + PREFIX_RP_OFF, sizeof (typeof (addr)));
	if (addr.sin_family)
		{
		*rp = [NSPort _newForSendingToSockaddr: &addr
					  withAcceptedSocket: s
					  pollingInPort: *sp];
		[(*rp) autorelease];
		}
    else
		*rp = nil;
	}
}

- (int) _fillFromSocket:(int)s			{ SUBCLASS; }
- (id) replyOutPort						{ return SUBCLASS; }
- (id) receivingInPort					{ return SUBCLASS; }

@end /* NSPortMessage (TcpInPacket) */


@implementation TcpInPacket

- (int) _fillFromSocket:(int)s
{
	int remaining = [_data length] - prefix - _eof;
	int c = TryRead(s, 1, [_data mutableBytes] + prefix + _eof, -remaining);

	if (c <= 0)
    	return EOF;
	_eof += c;

	return remaining - c;
}

@end /* TcpInPacket */



@interface NSPort (TcpOutPort)
- (struct sockaddr_in*) _remoteInPortSockaddr;
@end /* NSPort (TcpOutPort) */

@interface NSPort (TcpInPort)
- (struct sockaddr_in*) _listeningSockaddr;
@end /* NSPort (TcpOutPort) */


@implementation TcpOutPacket

+ (unsigned) prefixSize					{ return PREFIX_SIZE; }

- (void) _writeToSocket:(int)s 
		   withSendPort:(id)sp
		   withReceivePort:(id)rp
		   timeout:(NSTimeInterval)timeout
{
	struct sockaddr_in *addr;
	int c;

	DBLog(@"%s: Write to socket %d\n", object_get_class_name (self), s);

				// Put the packet size in the first four bytes of the packet.
	NSAssert(prefix == PREFIX_SIZE, NSInternalInconsistencyException);
	*(PREFIX_LENGTH_TYPE*)[_data mutableBytes] = NSSwapBigIntToHost(_eof);

	addr = [sp _remoteInPortSockaddr];
		// Put the sockaddr_in for replies in the next bytes of the prefix
		// region.  If there is no reply address specified, fill it with zeros.
	if (addr)	// Use memcpy instead of simply casting the ptr because some
				// systems fail to do the cast correctly (alignment issues?)
		memcpy([_data mutableBytes] + PREFIX_SP_OFF, addr,PREFIX_ADDRESS_SIZE);
	else
		memset([_data mutableBytes] + PREFIX_SP_OFF, 0, PREFIX_ADDRESS_SIZE);

	addr = [rp _listeningSockaddr];
		// Put the sockaddr_in for the destination in next bytes of the prefix
		// region.  If no destination address is specified, fill with zeros.
	if (addr)	// Use memcpy instead of simply casting the ptr because some
				// systems fail to do the cast correctly (alignment issues?)
		memcpy ([_data mutableBytes]+PREFIX_RP_OFF, addr, PREFIX_ADDRESS_SIZE);
	else
		memset ([_data mutableBytes]+PREFIX_RP_OFF, 0, PREFIX_ADDRESS_SIZE);

											// Write the packet on the socket.
	c = TryWrite (s, (int)timeout, (unsigned char*)[_data bytes], prefix+_eof);
	if (c == -2)
		[NSException raise: NSPortTimeoutException
					 format:@"[TcpOutPort -_writeToSocket:] write()timed out"];
	else
		if (c < 0)
			[NSException raise: NSInternalInconsistencyException
						 format: @"[TcpOutPort -_writeToSocket:] write(): %s",
								strerror(errno)];

	if (c != prefix + _eof) 
		[NSException raise: NSInternalInconsistencyException
					 format:@"TcpOutPort -_writeToSocket: partial write(): %s",
							strerror(errno)];
}

@end /* TcpOutPacket */
