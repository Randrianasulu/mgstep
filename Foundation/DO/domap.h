/* 
   Communications protocol to mGSTEP Distributed Objects name server

   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	October 1996

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

/*
 *
 *	Each request is a single message consisting of -
 *		a single byte request type,
 *		a single byte giving name length,
 *		a single byte specifying the type of port being registered
 *		or looked up, or a nul byte for probe operations.
 *		a single nul byte.
 *		a four byte port number in network byte order must be
 *		present for register operations, otherwise this is zero.
 *		a service name of 0 to GDO_NAME_MAX_LEN bytes (or two IP
 *		addresses in network byte order and an optional list of
 *		additional addresseso for probe operations)
 *		0 to GDO_NAME_MAX_LEN nul bytes padding the service name to its
 *		full size.
 *		a terminating nul byte.
 *		The total is always sent in a packet with everything after the
 *		service name (except the final byte) cleared to nul bytes.
 *
 *	Each response consists of at least 4 bytes and depends on the
 *	corresponding request type and where it came from as follows -
 *
 *	DO_LOOKUP	Looks up the server name and returns its port number.
 *			Response is the port number in network byte order,
 *			or zero if the named server was not registered.
 *
 *	DO_REGISTER	Registers the given server name with a port number.
 *			This service is only available to processes on the
 *			same host as the name server.
 *			Response is the port number in network byte order,
 *			or zero if the named server was already registered.
 *
 *	DO_UNREG	Un-register the server name and return old port number.
 *			If the server name is of length zero, and the port is
 *			non-zero then all names for the port are unregistered.
 *			This service is only available to a process on the
 *			same host as this name server.
 *			Response is the old port number in network byte order,
 *			or zero if the name could not be un-registered.
 *			If multiple names were unregistered the response is
 *			the port for those names.
 *
 *
 *	HOW IT WORKS AND WHY (implementation notes)
 *
 *	1.  The fixed size of a request packet was chosen for maximum
 *	    ease and speed of implementation of a non-blocking name server.
 *	    The server knows how much it needs to read and can therefore
 *	    usually do a read as a single operation since it doesn't have
 *	    to read a little, figure out request length, allocate a buffer,
 *	    and read the rest.
 *
 *	    The server name length (bytes) is specified - no assumptions
 *	    should be made about whether the name contains nul characters
 *	    or indeed about the name at all.  This is future-proofing.
 *
 *	3.  Port type codes - these are used to say what the port is for so
 *	    that clients can look up only the names that are relevant to them.
 *	    This is to permit the name server to be used for multiple
 *	    communications protocols (at the moment, tcp or udp) and for
 *	    different systems (distributed objects or others).
 *	    This guarantees that if one app is using DO over UDP, its services
 *	    will not be found by an app which is using DO over TCP.
 */

#define	GDOMAP_PORT	(538)	/* The well-known port for name server.	*/

/*
 *	Request type codes
 */
#define	GDO_REGISTER	'R'
#define	GDO_LOOKUP	'L'
#define	GDO_UNREG	'U'
#define	GDO_SERVERS	'S'
#define	GDO_PROBE	'P'
#define	GDO_PREPLY	'p'

/*
 *	Port type codes
 */
#define	GDO_NET_MASK	0x70	/* Network protocol of port.		*/
#define	GDO_NET_TCP	0x10
#define	GDO_NET_UDP	0x10
#define	GDO_SVC_MASK	0x0f	/* High level protocol of port.		*/
#define	GDO_SVC_GDO	0x01
#define	GDO_SVC_FOREIGN	0x02

/* tcp/ip distributed object server.	*/
#define	GDO_TCP_GDO	(GDO_NET_TCP|GDO_SVC_GDO)

/* udp/ip distributed object server.	*/
#define	GDO_UDP_GDO	(GDO_NET_UDP|GDO_SVC_GDO)

/* tcp/ip simple socket connection.	*/
#define	GDO_TCP_FOREIGN	(GDO_NET_TCP|GDO_SVC_FOREIGN)

/* udp/ip simple socket connection.	*/
#define	GDO_UDP_FOREIGN	(GDO_NET_UDP|GDO_SVC_FOREIGN)


#define	GDO_NAME_MAX_LEN	255	/* Max length registered name.	*/

/*
 *	Structure to hold a request.
 */
typedef	struct	{
    unsigned char	rtype;		/* Type of request being made.	*/
    unsigned char	nsize;		/* Length of the name to use.	*/
    unsigned char	ptype;		/* Type of port registered.	*/
    unsigned char	dummy;
    unsigned int	port;
    char name[GDO_NAME_MAX_LEN+1];
} do_req;

#define	DO_REQ_SIZE	sizeof(do_req)	/* Size of a request packet.	*/
