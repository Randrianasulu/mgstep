/*
   NSConnection.m

   Connection object for remote object messaging

   Copyright (C) 1994-2016 Free Software Foundation, Inc.

   Created by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   OPENSTEP by: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

// To do: Make it thread-safe.
// RMC == Remote Method Coder, or Remote Method Call.
//   It's an instance of PortEncoder or PortDecoder.

#include <Foundation/NSConnection.h>
#include <Foundation/NSDistantObject.h>

#include "_NSPortCoder.h"

#include <Foundation/NSPort.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSData.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSPortMessage.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSInvocation.h>

#include <Foundation/NSRunLoop.h>
#include <CoreFoundation/CFRunLoop.h>

#define PROXIES_HASH_GATE		nil
#define SEQUENCE_NUMBER_GATE	nil

#define ENCODED_RETNAME  __enc_retname


// Class variables
static unsigned __local_object_counter = 0;

static NSTimer *timer;

static int debug_connection = 1;

static NSHashTable *connection_table;
static NSLock *connection_table_gate;

static NSMutableDictionary *root_object_dictionary;
static NSLock *root_object_dictionary_gate;

static NSMapTable *receive_port_2_ancestor;

static NSMapTable *all_connections_local_objects = NULL;
static NSMapTable *all_connections_local_targets = NULL;
static NSMapTable *all_connections_local_cached = NULL;

// rmc handling
static NSMutableArray *received_request_rmc_queue;
static NSLock *received_request_rmc_queue_gate;
static NSMutableArray *received_reply_rmc_queue;
static NSLock *received_reply_rmc_queue_gate;

static int messages_received_count;

//
//  Keys for the NSDictionary returned by [NSConnection -statistics]
//
														// OPENSTEP 4.2
NSString *NSConnectionRepliesReceived  = @"NSConnectionRepliesReceived";
NSString *NSConnectionRepliesSent      = @"NSConnectionRepliesSent";
NSString *NSConnectionRequestsReceived = @"NSConnectionRequestsReceived";
NSString *NSConnectionRequestsSent     = @"NSConnectionRequestsSent";
														// mGSTEP extensions
NSString *NSConnectionLocalCount = @"NSConnectionLocalCount";
NSString *NSConnectionProxyCount = @"NSConnectionProxyCount";

NSString* NSConnectionReplyMode = @"NSConnectionReplyMode";

													// Notification Strings.
NSString *NSConnectionDidDieNotification = @"NSConnectionDidDieNotification";
NSString *NSConnectionDidInitializeNotification = 
			@"NSConnectionDidInitializeNotification";

static NSString *__enc_qrgname = @"argument value";
static NSString *__enc_retname = @"return value";


@interface	NSDistantObject (NSConnection)
- (id) localForProxy;
- (void) setProxyHandle:(NSUInteger)target;
- (NSUInteger) handleForProxy;
@end

@implementation	NSDistantObject (NSConnection)
- (id) localForProxy						{ return _local; }
- (void) setProxyHandle:(NSUInteger)handle	{ _handle = handle; }
- (NSUInteger) handleForProxy				{ return _handle; }
@end

											// GSLocalCounter is a trivial
@interface GSLocalCounter : NSObject		// class to keep track of how many
{											// different connections a given
@public										// local object is vended over.
	NSUInteger ref;							// This is required so that we know
	NSUInteger target;						// when to remove an object from
	id object;								// the global list when it is
}											// removed from the list of objects
											// vended on a given connection.
+ (GSLocalCounter*) newWithObject:(id)ob;

@end

@implementation	GSLocalCounter

+ (GSLocalCounter*) newWithObject:(id)obj
{
	GSLocalCounter *counter = (GSLocalCounter*)NSAllocateObject(self);

	counter->ref = 1;
	counter->object = [obj retain];
	counter->target = ++__local_object_counter;

	return counter;
}

- (void) dealloc
{
	[object release];
	[super dealloc];
}

@end

//	CachedLocalObject is a trivial class to keep track of how
//	many different connections a particular local object is vended
//	over.  This is required so that we know when to remove an object
//	from the global list when it is removed from the list of objects
//	vended on a particular connection.

@interface	CachedLocalObject : NSObject
{
	id _obj;
	int time;
}

- (BOOL) countdown;
- (id) obj;
+ (CachedLocalObject*) itemWithObject:(id)o time:(int)t;

@end

@implementation	CachedLocalObject

+ (CachedLocalObject*) itemWithObject:(id)o time:(int)t
{
	CachedLocalObject *item = [[self alloc] init];

	item->_obj = [o retain];
	item->time = t;
	
	return [item autorelease];
}

- (void) dealloc
{
	[_obj release];
	[super dealloc];
}

- (BOOL) countdown				{ return (time-- > 0) ? YES : NO; }
- (id) obj						{ return _obj; }

@end


@interface NSConnection (GettingCoderInterface)
- (void) _handleRmc:rmc;
- (void) _handleQueuedRmcRequests;
- (id) _getReceivedReplyRmcWithSequenceNumber:(int)n;
- (id) newSendingRequestRmc;
- (id) newSendingReplyRmcWithSequenceNumber:(int)n;
- (int) _newMsgNumber;
@end


@implementation NSConnection

+ (void) initialize
{
	connection_table = NSCreateHashTable (NSNonRetainedObjectHashCallBacks, 0);
	connection_table_gate = [NSLock new];
						// FIX ME When NSHashTable's are working, change this.
	all_connections_local_objects = 
					NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
								NSObjectMapValueCallBacks, 0);
	all_connections_local_targets = NSCreateMapTable (NSIntMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
	all_connections_local_cached = NSCreateMapTable (NSIntMapKeyCallBacks,
										NSObjectMapValueCallBacks, 0);
	received_request_rmc_queue = [[NSMutableArray alloc] initWithCapacity:32];
	received_request_rmc_queue_gate = [NSLock new];
	received_reply_rmc_queue = [[NSMutableArray alloc] initWithCapacity:32];
	received_reply_rmc_queue_gate = [NSLock new];
	root_object_dictionary = [[NSMutableDictionary alloc] initWithCapacity:8];
	root_object_dictionary_gate = [NSLock new];
	receive_port_2_ancestor =NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
										NSNonOwnedPointerMapValueCallBacks, 0);
	messages_received_count = 0;
}

+ (NSArray*) allConnections
{
	return NSAllHashTableObjects(connection_table);
}

+ (NSConnection*) connectionWithRegisteredName:(NSString*)n  host:(NSString*)h
{
	NSDistantObject	*proxy;

    if ((proxy = [self rootProxyForConnectionWithRegisteredName:n host:h]))
		return [proxy connectionForProxy];

    return nil;
}
			// Return the default connection for a thread. Possible problem - 
			// if the connection is invalidated, it won't be cleaned up until 
			// this thread calls this method again.  The connection and it's 
			// ports could hang around for a very long time.
+ (NSConnection*) defaultConnection
{
	static NSString *tkey = @"NSConnectionThreadKey";
	NSMutableDictionary *d = [[NSThread currentThread] threadDictionary];
	NSConnection *c;

	if ((c = (NSConnection*)[d objectForKey:tkey]) != nil)
		{
		if([c isValid])
			return c;
													// default connection for 
		[d removeObjectForKey:tkey];				// this thread has been
		}											// invalidated.  release it
													// and create a new one
	[d setObject:(c = [NSConnection new]) forKey:tkey];
	[c release];									// retained in dictionary.

	return c;
}

+ (NSConnection*) connectionWithReceivePort:(NSPort*)r
								   sendPort:(NSPort*)s
{
	return [[self _connectionWithReceivePort:r sendPort:s] autorelease];
}

- (id) initWithReceivePort:(NSPort*)r sendPort:(NSPort*)s
{
    [self dealloc];

	return [NSConnection _connectionWithReceivePort:r sendPort:s];
}

+ (id) new
{
	id r = [[[NSPort _inPortClass] newForReceiving] autorelease];

	return [[self alloc] initWithReceivePort:r sendPort:nil];
}

- (id) init
{
	id r = [[[NSPort _inPortClass] newForReceiving] autorelease];

	return [self initWithReceivePort:r sendPort:nil];
}

+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName:(NSString*)n
														 host:(NSString*)h
{
	id op = [[NSPort _outPortClass] newForSendingToRegisteredName:n onHost:h];

	if (op)
		{
		NSConnection *c = [self _connectionByOutPort: [op autorelease]];
		id newInPort;

		if (c)
			return [c rootProxy];

		newInPort = [[[NSPort _inPortClass] newForReceiving] autorelease];
		c = [self connectionWithReceivePort:newInPort sendPort:op];

		return [c rootProxy];
		}

    return (NSDistantObject*)nil;
}

+ (void) _timeout:(NSTimer*)t
{
	NSArray	*cached_locals = NSAllMapTableValues(all_connections_local_cached);
	int	i;

    for (i = [cached_locals count]; i > 0; i--) 
		{
		CachedLocalObject *item = [cached_locals objectAtIndex: i-1];

		if ([item countdown] == NO) 
			{
			GSLocalCounter *counter = [item obj];
			NSMapRemove(all_connections_local_cached, INT2PTR(counter->target));
		}	}

    if ([cached_locals count] == 0) 
		{
		[t invalidate];
		timer = nil;
		}
}

- (void) dealloc
{
	if (debug_connection)
		NSLog(@"deallocating 0x%x\n", self);

	[super dealloc];
}

- (id) delegate										{ return delegate; }
- (void) setDelegate:(id)anObj						{ delegate = anObj; }
- (void) setReplyTimeout:(NSTimeInterval)to			{ reply_timeout = to; }
- (void) setRequestTimeout:(NSTimeInterval)to		{ request_timeout = to; }
- (NSPort*) receivePort								{ return receive_port; }
- (NSPort*) sendPort								{ return send_port; }
- (void) runInNewThread								{ NIMP }
- (void) handlePortMessage:(NSPortMessage*)msg		{ NIMP }
- (void) enableMultipleThreads						{ NIMP }
- (void) removeRunLoop:(NSRunLoop *)runloop			{ NIMP }
- (NSTimeInterval) replyTimeout						{ return reply_timeout; }
- (NSTimeInterval) requestTimeout					{ return request_timeout; }
- (NSArray *) remoteObjects							{ NIMP return nil; }
+ (void) _setDebug:(int)val							{ debug_connection = val; }
- (BOOL) multipleThreadsEnabled						{ NIMP return NO; }
- (BOOL) isValid									{ return is_valid; }

- (BOOL) independentConversationQueueing
{
	return independant_queueing;
}

- (void) setIndependentConversationQueueing:(BOOL)flag
{
	independant_queueing = flag;
}

- (BOOL) registerName:(NSString*)name
{
	receive_port =[[NSPort _inPortClass] newForReceivingFromRegisteredName:name
										 fromPort:[receive_port portNumber]];
	return YES;
}

- (void) invalidate										// This needs locks
{
	if (is_valid == NO)
		return;

	is_valid = NO;
			// Don't need notifications any more - so remove self as observer.
	[[NSNotificationCenter defaultCenter] removeObserver: self];

					// We can't be the ancestor of anything if we are invalid.
	if (self == NSMapGet(receive_port_2_ancestor, receive_port))
		NSMapRemove(receive_port_2_ancestor, receive_port);

				// If we have been invalidated, we don't need to retain proxies
				// for local objects any more.  In fact, we want to get rid of
				// these proxies in case they are keeping us retained when we
	{			// might otherwise de deallocated.
    NSArray *targets;
    unsigned i;

    [PROXIES_HASH_GATE lock];
    [(targets = NSAllMapTableValues(local_targets)) retain];
	for (i = 0; i < [targets count]; i++)
		{
		id t = [[targets objectAtIndex:i] localForProxy];

		[self removeLocalObject: t];
		}
	[targets release];
    [PROXIES_HASH_GATE unlock];
	}

	if (debug_connection)
		NSLog(@"Invalidating connection 0x%x\n\t%@\n\t%@\n", self,
				[receive_port description], [send_port description]);

			// We need to notify any watchers of our death - but if we are
			// already in deallocation process, we can't have a notification
			// retaining and autoreleasing us later once we are deallocated
			// so we do the notification with a local autorelease pool to
	{		// ensure that any release is done before deallocation completes.
	NSAutoreleasePool *arp = [NSAutoreleasePool new];

	[NSNotificationCenter post:NSConnectionDidDieNotification object:self];

	[arp release];
	}
}

- (oneway void) release
{				// If this would cause the connection to be deallocated then we
				// must perform all necessary work (done in [-gcFinalize]).
				// We bracket the code with a retain and release so that any
				// retain/release pairs in the code won't cause recursion.
	if ([self retainCount] == 1)
		{
		[super retain];
		[self gcFinalize];
		[super release];
		}

	[super release];
}

- (void) addRequestMode:(NSString*)mode
{
	if ([request_modes containsObject: mode])
		return;

	if (receive_port->_cfSocket)
		{
		NSRunLoop *rl = (NSRunLoop*)CFRunLoopGetCurrent();

		[request_modes addObject:mode];
		[receive_port addConnection: self toRunLoop: rl forMode: mode];
		}
	else
		NSLog(@"NSConnection addRequestMode  ******** NO CF Socket present");
}

- (void) removeRequestMode:(NSString*)mode
{
	if ([request_modes containsObject: mode])
		{
		CFSocket *cfs = receive_port->_cfSocket;
		CFRunLoopSourceRef src = cfs->runLoopSource;

		[request_modes removeObject:mode];
		CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, (CFStringRef)mode);
// 		CFSocketDisableCallBacks (CFSocketRef socket, RL_ACCEPT)
		}
}

- (NSArray*) requestModes
{
	return [[request_modes copy] autorelease];
}

- (id) rootObject
{
	return [[self class] rootObjectForInPort: receive_port];
}

- (NSDistantObject*) rootProxy
{
	NSDistantObject *newProxy = nil;
	int seq_num = [self _newMsgNumber];

	NSParameterAssert(receive_port);
	NSParameterAssert (is_valid);

	id op = [_encodingClass newForWritingWithConnection: self
							sequenceNumber: seq_num
							identifier: ROOTPROXY_REQUEST];
	[op dismiss];

	id ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
	[ip decodeObjectAt: &newProxy withName: NULL];
	NSParameterAssert (_classIsKindOfClass (newProxy->isa, objc_get_class("NSDistantObject")));
	[ip dismiss];

	return [newProxy autorelease];
}

- (void) setRootObject:(id)anObj
{
	[[self class] setRootObject: anObj forInPort: receive_port];
}

- (NSDictionary*) statistics
{
	NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity: 8];
	id o;
												// These are in OPENSTEP 4.2
	o = [NSNumber numberWithUnsignedInt: rep_in_count];
	[d setObject: o forKey: NSConnectionRepliesReceived];
	o = [NSNumber numberWithUnsignedInt: rep_out_count];
	[d setObject: o forKey: NSConnectionRepliesSent];
	o = [NSNumber numberWithUnsignedInt: req_in_count];
	[d setObject: o forKey: NSConnectionRequestsReceived];
	o = [NSNumber numberWithUnsignedInt: req_out_count];
	[d setObject: o forKey: NSConnectionRequestsSent];
												// These are mGSTEP extras
	o = [NSNumber numberWithUnsignedInt: NSCountMapTable(local_targets)];
	[d setObject: o forKey: NSConnectionLocalCount];
	o = [NSNumber numberWithUnsignedInt: NSCountMapTable(remote_proxies)];
	[d setObject: o forKey: NSConnectionProxyCount];
	[received_request_rmc_queue_gate lock];
	o = [NSNumber numberWithUnsignedInt: [received_request_rmc_queue count]];
	[received_request_rmc_queue_gate unlock];
	[d setObject: o forKey: @"Pending packets"];
	
	return d;
}

@end  /* NSConnection */


@implementation	NSConnection (mGSTEPExtensions)

- (void) gcFinalize
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

	if (debug_connection)
		NSLog(@"finalising 0x%x\n", self);

	[self invalidate];
	[connection_table_gate lock];
	NSHashRemove(connection_table, self);
	[timer invalidate];
	timer = nil;
	[connection_table_gate unlock];
							// Remove rootObject from root_object_dictionary
							// if this is last connection 
	if (![NSConnection connectionsCountWithInPort:receive_port])
		[NSConnection setRootObject:nil forInPort:receive_port];
										// Remove receive port from run loop
	[self removeRequestMode: NSDefaultRunLoopMode];
	[self removeRequestMode: NSConnectionReplyMode];
	while ([request_modes count])
		[self removeRequestMode: [request_modes objectAtIndex: 0]];
	[request_modes release];

	[receive_port release];				// Finished with ports - releasing
	[send_port release];				// them may generate a notification
	
	[PROXIES_HASH_GATE lock];
	NSFreeMapTable (remote_proxies);
	NSFreeMapTable (local_objects);
	NSFreeMapTable (local_targets);
	NSFreeMapTable (incoming_xref_2_const_ptr);
	NSFreeMapTable (outgoing_const_ptr_2_xref);
	[PROXIES_HASH_GATE unlock];
	
	[pool release];
}

+ (NSConnection*) _connectionByInPort:(NSPort*)ip outPort:(NSPort*)op
{
	NSHashEnumerator enumerator;
	NSConnection *o;

	NSParameterAssert (ip);

	[connection_table_gate lock];

	enumerator = NSEnumerateHashTable(connection_table);
	while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
		{
		id newConnInPort = [o receivePort];
		id newConnOutPort = [o sendPort];

		if ([newConnInPort isEqual: ip] && [newConnOutPort isEqual: op])
			{
			[connection_table_gate unlock];
			return o;
		}	}
	[connection_table_gate unlock];
	
	return nil;
}

+ (NSConnection*) _connectionByOutPort:(NSPort*)op
{
	NSHashEnumerator enumerator;
	NSConnection *o;

	NSParameterAssert (op);
	
	[connection_table_gate lock];
	
	enumerator = NSEnumerateHashTable(connection_table);
	while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
		{
		id newConnOutPort = [o sendPort];

		if ([newConnOutPort isEqual: op])
			{
			[connection_table_gate unlock];
			return o;
		}	}
	[connection_table_gate unlock];
	
	return nil;
}
										// Class-wide stats and collections.
+ (int) messagesReceived				{ return messages_received_count; }

+ (unsigned) connectionsCount
{
	return NSCountHashTable(connection_table);
}

+ (unsigned) connectionsCountWithInPort:(NSPort*)aPort
{
	unsigned count = 0;
	NSHashEnumerator enumerator;
	NSConnection *o;

	[connection_table_gate lock];
	enumerator = NSEnumerateHashTable(connection_table);
	while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
		if ([aPort isEqual: [o receivePort]])
			count++;

	[connection_table_gate unlock];

	return count;
}

+ (NSDistantObject*) rootProxyAtName:(NSString*)n
{
	return [self rootProxyAtName: n onHost: @""];
}

+ (NSDistantObject*) rootProxyAtName:(NSString*)n onHost:(NSString*)h
{
	return [self rootProxyForConnectionWithRegisteredName:n host:h];
}

+ (NSConnection*) _connectionWithReceivePort:(NSPort*)ip
									sendPort:(NSPort*)op
{
	NSConnection *newConn;
	NSConnection *ancestor;
	NSNotificationCenter *nc;		// designated initializer for NSConnection

	if (!ip)
		{
//		NSParameterAssert (ip);
		if (!op)
			return _NSLogError(@"NSConnection: can't init with nil ports");
		
//		r = [[[op class] new] autorelease];
		ip = [[[NSPort _inPortClass] newForReceiving] autorelease];
		}
	else if (!op)
		op = ip;
									// Find pre-existing connection if there is 
	if ((newConn = [self _connectionByInPort: ip outPort: op]))
		{
		if (debug_connection > 2)
			NSLog(@"Found existing connection (0x%x) for \n\t%@\n\t%@\n",
					newConn, [ip description], [op description]);

		return [newConn retain];
		}
	[connection_table_gate lock];

	newConn = [NSConnection alloc];
//	if (debug_connection)
//		NSLog(@"Created new connection 0x%x\n\t%@\n\t%@\n",
//				newConn, [ip description], [op description]);
	newConn->is_valid = YES;
	newConn->receive_port = ip;
	[ip retain];
	newConn->send_port = op;
	[op retain];

			// This maps (void*)obj to (id)obj.  The obj's are retained. We use
			// this instead of an NSHashTable because we only care about the
			// object's address, and don't want to send the -hash message to it
	newConn->local_objects = NSCreateMapTable ( 
								NSNonOwnedPointerMapKeyCallBacks,
								NSObjectMapValueCallBacks, 0);

				// This maps handles for local objects to their local proxies.
	newConn->local_targets = NSCreateMapTable (NSIntMapKeyCallBacks,
								NSNonOwnedPointerMapValueCallBacks, 0);

	   // This maps [proxy handleForProxy] to proxy.  The proxy's are retained.
	newConn->remote_proxies = NSCreateMapTable (NSIntMapKeyCallBacks,
								NSNonOwnedPointerMapValueCallBacks, 0);

	newConn->incoming_xref_2_const_ptr = NSCreateMapTable ( 
								NSIntMapKeyCallBacks,
								NSNonOwnedPointerMapValueCallBacks, 0);
	newConn->outgoing_const_ptr_2_xref = NSCreateMapTable ( 
								NSIntMapKeyCallBacks,
								NSNonOwnedPointerMapValueCallBacks, 0);

	newConn->reply_timeout = CONNECTION_TIMEOUT;
	newConn->request_timeout = CONNECTION_TIMEOUT;
	newConn->_encodingClass = [NSPortCoder class];

							// FIX ME ANCESTOR argument was ignored; 
							// in the future it will be removed.
							// FIX ME It this the correct behavior? 
	if (!(ancestor = NSMapGet (receive_port_2_ancestor, ip)))
		{
		NSMapInsert (receive_port_2_ancestor, ip, newConn);
		/* This will cause the connection with the registered name
		to receive the -invokeWithObject: from the IN_PORT.
		This ends up being the ancestor of future new NSConnections
		on this in port. */
		/* xxx Could it happen that this connection was invalidated, but
		the others would still be OK?  That would cause problems.
		No.  I don't think that can happen. */
		[(NSPort*)ip setReceivedPacketInvocation: (id)[self class]];
		}

	if (ancestor)
		{
		newConn->receive_port_class = [ancestor receivePortClass];
		newConn->send_port_class = [ancestor sendPortClass];
		}
	else
		{
		newConn->receive_port_class = [NSPort _inPortClass];
		newConn->send_port_class = [NSPort _outPortClass];
		}
						// Set up request modes array and make sure the 
						// receiving port is added to the run loop to get data.
	newConn->request_modes = [[NSMutableArray arrayWithObject:
							NSDefaultRunLoopMode] retain];
	if (ip->_cfSocket)
		{
		CFRunLoopRef rl = CFRunLoopGetCurrent();
		CFRunLoopSourceRef rs;

		if ((rs = CFSocketCreateRunLoopSource(NULL, ip->_cfSocket, 0)) == NULL)
			[NSException raise:NSGenericException format:@"CFSocket init error"];

		CFRunLoopAddSource(rl, rs, (CFStringRef)NSDefaultRunLoopMode);
		CFRunLoopAddSource(rl, rs, (CFStringRef)NSConnectionReplyMode);
		CFRelease(rs);
		[newConn->request_modes addObject:NSConnectionReplyMode];
		}
	else
		NSLog(@"NSConnection  ******** No CF Socket present");

	nc = [NSNotificationCenter defaultCenter];		// Register ourselves for 
	[nc addObserver: newConn						// invalidation notice when 
		selector: @selector(portIsInvalid:)			// the ports become invalid
		name: NSPortDidBecomeInvalidNotification
		object: ip];

	if (op)
		[nc addObserver: newConn
			selector: @selector(portIsInvalid:)
			name: NSPortDidBecomeInvalidNotification
			object: op];		// if OP is nil, making this notification 
								// request would have registered us to receive
								// all NSPortDidBecomeInvalidNotification
								// requests, independent of which port posted 
								// them.  This isn't what we want.
		// So that connections may be deallocated there is an implementation
		// of -release to automatically remove the connection from this array 
		// when it is the only object retaining it.
	NSHashInsert(connection_table, (void*)newConn);
	[connection_table_gate unlock];

	[NSNotificationCenter post: NSConnectionDidInitializeNotification 
						  object: newConn];

	return newConn;
}
					// Creating new rmc's for encoding requests and replies
- (id) newSendingRequestRmc
{											// Create a new, empty rmc, which 
	id rmc;									// will be filled with a request.

	NSParameterAssert(receive_port);
	NSParameterAssert (is_valid);
	rmc = [_encodingClass newForWritingWithConnection: self
						  sequenceNumber: [self _newMsgNumber]
						  identifier: METHOD_REQUEST];
	return rmc;
}
	// Create a new, empty rmc, which will be filled with a reply to msg #n. 
- (id) newSendingReplyRmcWithSequenceNumber:(int)n
{
	id rmc = [_encodingClass newForWritingWithConnection: self
							 sequenceNumber: n
							 identifier: METHOD_REPLY];
	NSParameterAssert (is_valid);
	
	return rmc;
}

- (void) forwardInvocation:(NSInvocation*)anInvocation
{									// NSDistantObject's -forward: method calls
	NSPortCoder <Encoding> *op;		// this to send the message over the wire.
    BOOL out_parameters;
    const char *type;
    int seq_num;
	SEL sel = [anInvocation selector];

	NSPortCoder <Decoding>*ip = nil;
	BOOL is_exception = NO;
	char *forward_type = NULL;			// NSConnection calls this to service

    NSParameterAssert (is_valid);

    type = sel_get_type(sel);

    if (type == 0 || *type == '\0') 
		{
		type = [[anInvocation methodSignatureForSelector: sel] methodType];

		if (type) 
			sel_register_typed_name(sel_get_name(sel), type);
		}
	NSParameterAssert(type);
	NSParameterAssert(*type);
									// get the method types from the selector
    op = [self newSendingRequestRmc];
    seq_num = [op sequenceNumber];
	if (debug_connection > 4)
		NSLog(@"building packet seq %d\n", seq_num);

				// Send the types that we're using, so that the performer knows
				// exactly what qualifiers we're using. If all selectors 
				// included qualifiers, and if I could make sel_types_match() 
				// work the way I wanted, we wouldn't need to do this.
    [op encodeValueOfCType: @encode(char*)
		at: &type
		withName: @"selector type"];

///	[op encodeObject: anInvocation withName: @"forward invocation"];
	[anInvocation encodeWithCoder: op];

//  out_parameters = mframe_dissect_call (argframe, type, encoder);
    [op dismiss];												// Send the rmc
    if (debug_connection > 1)
		NSLog(@"Sent message to 0x%x\n", self);
    req_out_count++;											// Sent request
	
	if (!ip)		// Get the reply rmc and decode it.
		{			// If we didn't get the reply packet yet, get it now.
		BOOL result;

		if (!is_valid)
			[NSException raise: NSGenericException
				format: @"connection waiting for request was shut down"];

				// FIX ME Why do we get the reply packet in here and not
				// just before calling dissect_method_return() below?
		ip = [self _getReceivedReplyRmcWithSequenceNumber:seq_num];
								// Find out if the server is returning an 
								// exception instead of the return values.
		[ip decodeValueOfCType:@encode(BOOL) 
			at:&is_exception 
			withName:NULL];
		if (is_exception)
			{					// Decode the exception object, and raise it.
			id exc;

			[ip decodeObjectAt: &exc withName: NULL];
			[ip dismiss];
			ip = (id)-1;
								// FIX ME Is there anything else to clean 
			[exc raise];		// up in dissect_method_return()
			}
		else
			{
			[ip decodeValueOfCType:@encode(char*)
				at:&forward_type 
				withName:NULL];
										// re-init invocation with reply packet
			[anInvocation initWithCoder: ip];
			}
		}

	NSAssert(ip == (id)-1 || ip == nil, NSInternalInconsistencyException);
	if (ip)
		rep_in_count++;											// received a reply
}
				// Methods for handling client and server, requests and replies
- (void) _service_forwardForProxy:aRmc
{
	char *forward_type = NULL;			// NSConnection calls this to service
	id op = nil;						// the incoming method request.
	int reply_sequence_number;

#ifndef __USE_LIBOBJC2__
	void decoder (int argnum, void *datum, const char *type)
		{	// Need this "dismiss" to happen here and not later so that Coder
			// "-awake..." methods will get sent before the __builtin_apply!
		if (argnum == -1 && datum == 0 && type == 0)
			{
			[aRmc dismiss];
			return;
			}

		[aRmc decodeValueOfObjCType:type at:datum withName:NULL];
						// -decodeValueOfCType:at:withName: malloc's new memory
						// for char*'s.  We need to make sure it gets freed 
						// eventually so we don't have a memory leak.  Request 
						// here that it be autorelease'ed. Also autorelease 
						// created objects.
		if (*type == _C_CHARPTR)
			[NSData dataWithBytesNoCopy: *(void**)datum length: 1];
		else 
			if (*type == _C_ID)
				[*(id*)datum autorelease];
		}

	void encoder (int argnum, const void *datum, const char *type, int flags)
		{
		if (op == nil)
			{
			BOOL is_exception = NO;
					// It is possible that our connection died while the method
					// was being called?  In which case we mustn't try to send 
					// the result back to the remote application!
			if (!is_valid)
				return;
			op = [self newSendingReplyRmcWithSequenceNumber: reply_sequence_number];
			[op encodeValueOfCType: @encode(BOOL)
				at: &is_exception
				withName: @"Exceptional reply flag"];
			}
				// Send the types that we're using, so that the performer knows
				// exactly what qualifiers we're using. If all selectors 
				// included qualifiers, and if I could make sel_types_match() 
				// work the way I wanted, we wouldn't need to do this.
//    [op encodeValueOfCType: @encode(char*)
//		at: &type
//		withName: @"selector type"];

		switch (*type)
			{
			case _C_ID:
				[(NSInvocation *)datum encodeWithCoder: op];
				break;
			default:
				[op encodeValueOfObjCType:type 
					at:&datum 
					withName:ENCODED_RETNAME];
			}
		}

	NS_DURING					// Make sure any exceptions caused by servicing
		{						// the client's request don't cause us to crash
		NSParameterAssert (is_valid);
														// Save this for later
		reply_sequence_number = [aRmc sequenceNumber];
								// Get the types that we're using, so that we 
								// know exactly what qualifiers the forwarder 
								// used.  If all selectors included qualifiers 
								// and I could make sel_types_match() work the 
								// way I wanted, we wouldn't need to do this.
		[aRmc decodeValueOfCType:@encode(char*) 
			  at:&forward_type 
			  withName:NULL];
		{
     	NSInvocation *invocation = nil;

		if (debug_connection > 1)
			NSLog(@"Handling message from 0x%x\n", self);
		req_in_count++;	/* Handling an incoming request. */
		mframe_do_call (forward_type, decoder, encoder);
		}

		[op dismiss];									// Send back a reply
		rep_out_count++;
		}
	NS_HANDLER		
		{			// Make sure we pass all exceptions back to the requestor.
		BOOL is_exception = YES;

		if (op)									// Try to clean up a little.
			[op release];

		if (is_valid)				// Send the exception back to the client.
			{
			op = [self newSendingReplyRmcWithSequenceNumber: 
						reply_sequence_number];
			[op encodeValueOfCType: @encode(BOOL)
				at: &is_exception
				withName: @"Exceptional reply flag"];
			[op encodeBycopyObject: localException
				withName: @"Exception object"];
			[op dismiss];
			}
		}
	NS_ENDHANDLER;

	if (forward_type)
		free (forward_type);
#endif
}

- (void) _service_rootObject:rmc
{
	id rootObject = [NSConnection rootObjectForInPort:receive_port];
	NSPortCoder <Encoding> *op;

	op = [_encodingClass newForWritingWithConnection: [rmc connection]
						 sequenceNumber: [rmc sequenceNumber]
						 identifier: ROOTPROXY_REPLY];
	NSParameterAssert (receive_port);
	NSParameterAssert (is_valid);
	/* Perhaps we should turn this into a class method. */
	NSParameterAssert([rmc connection] == self);
	[op encodeObject: rootObject withName: @"root object"];
	[op dismiss];
	[rmc dismiss];
}

- (void) _service_release:rmc forConnection:receiving_connection
{
	unsigned int count;
	unsigned int pos;

	NSParameterAssert (is_valid);

	if ([rmc connection] != self)
		{
		[rmc dismiss];
		[NSException raise: @"ProxyDecodedBadTarget"
					 format: @"request to release object on bad connection"];
		}

	[rmc decodeValueOfCType: @encode(typeof(count))
		 at: &count
		 withName: NULL];

	for (pos = 0; pos < count; pos++)
		{
		NSUInteger target;
		NSDistantObject *prox;

		[rmc decodeValueOfCType: @encode(typeof(target))
			 at: &target
		     withName: NULL];

		prox = (NSDistantObject*)[self includesLocalTarget: target];
		if (prox != nil)
			{
			if (debug_connection > 3)
				NSLog(@"releasing object with target (0x%x) on (0x%x)",
						target, self);
			[self removeLocalObject: [prox localForProxy]];
			}
		else 
			if (debug_connection > 3)
		NSLog(@"releasing object with target (0x%x) on (0x%x) - nothing to do",
				target, self);
		}

	[rmc dismiss];
}

- (void) _service_retain:rmc forConnection:receiving_connection
{
	NSUInteger target;
	NSPortCoder	<Encoding> *op;

	NSParameterAssert (is_valid);
	
	if ([rmc connection] != self)
		{
		[rmc dismiss];
		[NSException raise: @"ProxyDecodedBadTarget"
					 format: @"request to retain object on bad connection"];
		}
	
	op = [_encodingClass newForWritingWithConnection: [rmc connection]
						 sequenceNumber: [rmc sequenceNumber]
						 identifier: RETAIN_REPLY];
	
	[rmc decodeValueOfCType: @encode(typeof(target))
		 at: &target
		 withName: NULL];
	
	if (debug_connection > 3)
		NSLog(@"looking to retain local object with target (0x%x) on (0x%x)",
				target, self);
	
	if ([self includesLocalTarget: target] == nil)
		{
		GSLocalCounter *counter;
	
		[PROXIES_HASH_GATE lock];
		counter = NSMapGet (all_connections_local_targets, UINT2PTR(target));
		if (counter == nil)
			{		// If the target doesn't exist for any connection, but 
					// still persists in the cache (ie it was recently 
					// released) then we move it back from the cache to the 
					// main maps so we can retain it on this connection.
			counter = NSMapGet (all_connections_local_cached, UINT2PTR(target));
			if (counter)
				{
				NSUInteger t = counter->target;
				id o = counter->object;
		
				NSMapInsert(all_connections_local_objects, o, counter);
				NSMapInsert(all_connections_local_targets, UINT2PTR(t), counter);
				NSMapRemove(all_connections_local_cached, UINT2PTR(t));
				if (debug_connection > 3)
					NSLog(@"target (0x%x) moved from cache", target);
				}
			}
		[PROXIES_HASH_GATE unlock];
		if (counter == nil)
			{
			[op encodeObject: @"target not found anywhere"
				withName: @"retain failed"];
			if (debug_connection > 3)
				NSLog(@"target (0x%x) not found anywhere for retain", target);
			}
		else
			{
			[NSDistantObject proxyWithLocal: counter->object
							 connection: self];
			[op encodeObject: nil withName: @"retain ok"];
			if (debug_connection > 3)
			 NSLog(@"retained object (0x%x) target (0x%x) on connection(0x%x)",
				counter->object, counter->target, self);
			}
		}
	else 
		{
		[op encodeObject: nil withName: @"already retained"];
		if (debug_connection > 3)
			NSLog(@"target (0x%x) already retained on connection (0x%x)",
					target, self);
		}
	
	[op dismiss];
	[rmc dismiss];
}

- (void) shutdown
{
	id op;

	NSParameterAssert(receive_port);
	NSParameterAssert (is_valid);
	op = [_encodingClass newForWritingWithConnection: self
						 sequenceNumber: [self _newMsgNumber]
						 identifier: CONNECTION_SHUTDOWN];
	[op dismiss];
}

- (void) _service_shutdown:rmc forConnection:receiving_connection
{
	NSParameterAssert (is_valid);
	[self invalidate];
	if (receiving_connection == self)
		[NSException raise: NSGenericException
					 format: @"connection waiting for request was shut down"];
	[rmc dismiss];
}

- (const char *) typeForSelector:(SEL)sel remoteTarget:(NSUInteger)target
{
	id op, ip;
	char *type = 0;
	int seq_num;

	NSParameterAssert(receive_port);
	NSParameterAssert (is_valid);
	seq_num = [self _newMsgNumber];
	op = [_encodingClass newForWritingWithConnection: self
						 sequenceNumber: seq_num
						 identifier: METHODTYPE_REQUEST];
	[op encodeValueOfObjCType:":" at:&sel withName:NULL];
	[op encodeValueOfCType:@encode(NSUInteger) at:&target withName:NULL];
	[op dismiss];
	ip = [self _getReceivedReplyRmcWithSequenceNumber:seq_num];
	[ip decodeValueOfCType:@encode(char*) at:&type withName:NULL];
	[ip dismiss];

	return type;
}

- (void) _service_typeForSelector:rmc
{
	NSPortCoder <Encoding> *op;
	NSUInteger target;
	NSDistantObject *p;
	id o;
	SEL sel;
	const char *type;
	struct objc_method* m;

	NSParameterAssert(receive_port);
	NSParameterAssert (is_valid);
	NSParameterAssert([rmc connection] == self);
	op = [_encodingClass newForWritingWithConnection: [rmc connection]
						 sequenceNumber: [rmc sequenceNumber]
						 identifier: METHODTYPE_REPLY];
	
	[rmc decodeValueOfObjCType:":" at:&sel withName:NULL];
	[rmc decodeValueOfCType:@encode(NSUInteger) at:&target withName:NULL];
	p = [self includesLocalTarget: target];
	o = [p localForProxy];
#ifdef NEW_RUNTIME
	m = class_getInstanceMethod (object_getClass(self), sel);

	if (!(type = method_getTypeEncoding (m)))
		type = "";
#else
						// FIX ME We should make sure that TARGET is a valid 
						// object. Not actually a Proxy, but we avoid the 
						// warnings "id" would have made.
	m = class_get_instance_method(((NSDistantObject*)o)->isa, sel);
						// Perhaps I need to be more careful in the line above 
						// to get the version of the method types that has the 
	if (m)				// type qualifiers in it. Search the protocols list.
		type = m->method_types;
	else
		type = "";
#endif
	[op encodeValueOfCType:@encode(char*)
		at:&type
		withName:@"Requested Method Type for Target"];
	[op dismiss];
	[rmc dismiss];
}

- (void) runConnectionUntilDate:date
{
	[[NSRunLoop currentRunLoop] runUntilDate: date];
}

- (void) runConnection
{
	[self runConnectionUntilDate: [NSDate distantFuture]];
}

- (void) _handleRmc:rmc
{
	NSConnection *conn = [rmc connection];
	int ident = [rmc identifier];

	if (debug_connection > 4)
	  NSLog(@"handling packet of type %d seq %d\n",ident,[rmc sequenceNumber]);

	switch (ident)
		{
		case ROOTPROXY_REQUEST:
			/* It won't take much time to handle this, so go ahead and service
			it, even if we are waiting for a reply. */
			[conn _service_rootObject: rmc];
			break;
		case METHODTYPE_REQUEST:
			/* It won't take much time to handle this, so go ahead and service
			it, even if we are waiting for a reply. */
			[conn _service_typeForSelector: rmc];
			break;
		case METHOD_REQUEST:
			/* We just got a new request; we need to decide whether to queue
			it or service it now.
			If the REPLY_DEPTH is 0, then we aren't in the middle of waiting
			for a reply, we are waiting for requests---so service it now.
			If REPLY_DEPTH is non-zero, we may still want to service it now
			if independant_queuing is NO. */
			if (reply_depth == 0 || independant_queueing == NO)
				{
				[conn _service_forwardForProxy: rmc];
				// Service any requests that were queued while we were waiting
				// for replies. Is this the right place for this check?
				if (reply_depth == 0)
					[self _handleQueuedRmcRequests];
				}
			else
				{
				[received_request_rmc_queue_gate lock];
				[received_request_rmc_queue addObject: rmc];
				[received_request_rmc_queue_gate unlock];
				}
			break;
		case ROOTPROXY_REPLY:
		case METHOD_REPLY:
		case METHODTYPE_REPLY:			// Remember multi-threaded callbacks
		case RETAIN_REPLY:				// will have to be handled specially
			[received_reply_rmc_queue_gate lock];
			[received_reply_rmc_queue addObject: rmc];
			[received_reply_rmc_queue_gate unlock];
			break;
		case CONNECTION_SHUTDOWN:
			{
			[conn _service_shutdown: rmc forConnection: self];
			break;
			}
		case PROXY_RELEASE:
			{
			[conn _service_release: rmc forConnection: self];
			break;
			}
		case PROXY_RETAIN:
			{
			[conn _service_retain: rmc forConnection: self];
			break;
			}
		default:
			[rmc dismiss];
			[NSException raise: NSGenericException
						 format: @"unrecognized NSPortCoder identifier"];
		}
}

- (void) _handleQueuedRmcRequests
{
	id rmc;

	[received_request_rmc_queue_gate lock];
	[self retain];
	while (is_valid && ([received_request_rmc_queue count] > 0))
		{
		rmc = [received_request_rmc_queue objectAtIndex: 0];
		[received_request_rmc_queue removeObjectAtIndex: 0];
		[received_request_rmc_queue_gate unlock];
		[self _handleRmc: rmc];
		[received_request_rmc_queue_gate lock];
		}
	[self release];
	[received_request_rmc_queue_gate unlock];
}

/* Deal with an RMC, either by queuing it for later service, or
   by servicing it right away.  This method is called by the
   receive_port's received-packet-invocation. */

/* Look for it on the queue, if it is not there, return nil. */
- _getReceivedReplyRmcFromQueueWithSequenceNumber:(int)sn
{
	id the_rmc = nil;
	unsigned count, i;

	[received_reply_rmc_queue_gate lock];
	
	count = [received_reply_rmc_queue count];
	/* xxx There should be a per-thread queue of rmcs so we can do
		callbacks when multi-threaded. */
	for (i = 0; i < count; i++)
		{
		id a_rmc = [received_reply_rmc_queue objectAtIndex: i];
		if ([a_rmc connection] == self && [a_rmc sequenceNumber] == sn)
			{
			if (debug_connection)
				NSLog(@"Getting received reply from queue\n");
			[received_reply_rmc_queue removeObjectAtIndex: i];
			the_rmc = a_rmc;
			break;
			}
		/* xxx Make sure that there isn't a higher sequenceNumber, meaning
		that we somehow dropped a packet. */
		}
	[received_reply_rmc_queue_gate unlock];
	
	return the_rmc;
}

/* Check the queue, then try to get it from the network by waiting
   while we run the NSRunLoop.  Raise exception if we don't get anything
   before timing out. */
- _getReceivedReplyRmcWithSequenceNumber:(int)sn
{
	id rmc;
	id timeout_date = nil;

	reply_depth++;
	while (!(rmc = [self _getReceivedReplyRmcFromQueueWithSequenceNumber: sn]))
		{
		if (!timeout_date)
			timeout_date = [[NSDate alloc]
				initWithTimeIntervalSinceNow: reply_timeout];
		if ([[NSRunLoop currentRunLoop] runMode: NSConnectionReplyMode 
										beforeDate: timeout_date] == NO)
		break;
		}
	if (timeout_date)
		[timeout_date release];
	reply_depth--;
	if (rmc == nil)
		[NSException raise: NSPortTimeoutException
					 format: @"timed out waiting for reply"];

	return rmc;
}

/* Sneaky, sneaky.  See "sneaky" comment in TcpPort.m.
   This method is called by InPort when it receives a new packet. */
+ (void) invokeWithObject:(id)packet
{
	id rmc;
	NSConnection *connection;

	if (debug_connection > 3)
		NSLog(@"packet arrived on %@", [[packet receivingInPort] description]);

	connection = NSMapGet(receive_port_2_ancestor, [packet receivingInPort]);
	if (connection && [connection isValid])
		{
		rmc = [PortDecoder newDecodingWithPacket:packet connection:connection];
		[[rmc connection] _handleRmc: rmc];
		}
	else
		[packet release];		/* Discard data on invalid connection.	*/
}

- (int) _newMsgNumber
{
	int n;

	NSParameterAssert (is_valid);
	[SEQUENCE_NUMBER_GATE lock];
	n = message_count++;
	[SEQUENCE_NUMBER_GATE unlock];
	
	return n;
}
												// Managing objects and proxies
- (void) addLocalObject:(id)anObj
{
	id object = [anObj localForProxy];
	NSUInteger target;
	GSLocalCounter *counter;

	NSParameterAssert (is_valid);
	[PROXIES_HASH_GATE lock];
	/* xxx Do we need to check to make sure it's not already there? */
	/* This retains object. */
	NSMapInsert(local_objects, (void*)object, anObj);
	
						// Keep track of local objects accross all connections.
	counter = NSMapGet(all_connections_local_objects, (void*)object);
	if (counter)
		{
		counter->ref++;
		target = counter->target;
		}
	else
		{
		counter = [GSLocalCounter newWithObject: object];
		target = counter->target;
		NSMapInsert(all_connections_local_objects, object, counter);
		NSMapInsert(all_connections_local_targets, UINT2PTR(target), counter);
		[counter release];
		}
	[anObj setProxyHandle: target];
	NSMapInsert(local_targets, UINT2PTR(target), anObj);
	if (debug_connection > 2)
		NSLog(@"add local object (0x%x) target (0x%x) to connection (0x%x) (ref %d)\n",
				object, target, self, counter->ref);
	[PROXIES_HASH_GATE unlock];
}

- (NSDistantObject*) localForObject:(id)object
{
	NSDistantObject *p;

	[PROXIES_HASH_GATE lock];						// Don't assert (is_valid);
	p = NSMapGet (local_objects, (void*)object);
	[PROXIES_HASH_GATE unlock];
	NSParameterAssert(!p || [p connectionForProxy] == self);
	
	return p;
}
					// This should get called whenever an object free's itself
+ (void) removeLocalObject:(id)anObj
{
	NSHashEnumerator enumerator = NSEnumerateHashTable(connection_table);
	NSConnection *o;

	while ((o = (NSConnection*)NSNextHashEnumeratorItem(&enumerator)) != nil)
		[o removeLocalObject: anObj];
}

- (void) removeLocalObject:(id)anObj
{
	NSDistantObject *prox;
	NSUInteger target;
	GSLocalCounter *counter;
	unsigned val = 0;

	[PROXIES_HASH_GATE lock];

	prox = NSMapGet(local_objects, (void*)anObj);
	target = (NSUInteger)[prox handleForProxy];
								// If all references to a local proxy have gone  
								// remove the global reference as well.
	counter = NSMapGet(all_connections_local_objects, (void*)anObj);
	if (counter)
		{
		counter->ref--;

		if ((val = counter->ref) == 0)
			{		// If this proxy has been vended onwards by another 
					// process, we need to keep a reference to the local object 
					// around for a while in case that other process needs it.
			if (0)
				{
				id item;

				if (timer == nil)
					{
					timer = [NSTimer scheduledTimerWithTimeInterval: 1.0
									target: [NSConnection class]
									selector: @selector(_timeout:)
									userInfo: nil
									repeats: YES];
					}
				item = [CachedLocalObject itemWithObject: counter time: 30];
				NSMapInsert(all_connections_local_cached, UINT2PTR(target), item);
				if (debug_connection > 3)
					NSLog(@"placed local object (0x%x) target (0x%x) in cache",
							anObj, target);
				}
			NSMapRemove(all_connections_local_objects, (void*)anObj);
			NSMapRemove(all_connections_local_targets, UINT2PTR(target));
		}	}

	NSMapRemove(local_objects, (void*)anObj);
	NSMapRemove(local_targets, UINT2PTR(target));
	
	if (debug_connection > 2)
		NSLog(@"remove local object (0x%x) target (0x%x) "
				@"from connection (0x%x) (ref %d)\n",
				anObj, target, self, val);
	
	[PROXIES_HASH_GATE unlock];
}

- (void) _release_targets:(NSUInteger*)list count:(unsigned)number
{
	NS_DURING
		{			// Tell the remote app that it can release its local 
					// objects for the targets in the specified list since we 
					// don't have proxies for them any more.
		if (receive_port && is_valid && number > 0) 
			{
			unsigned i;
			id op = [_encodingClass newForWritingWithConnection: self
									sequenceNumber: [self _newMsgNumber]
									identifier: PROXY_RELEASE];

			[op encodeValueOfCType:@encode(unsigned) at:&number withName:NULL];
		
			for (i = 0; i < number; i++)
				{
				[op encodeValueOfCType:@encode(NSUInteger) 
					at:&list[i]
					withName:NULL];
				if (debug_connection > 3)
					NSLog(@"sending release for target (0x%x) on (0x%x)",
							list[i], self);
				}
		
			[op dismiss];
		}	}
	NS_HANDLER
		{
		if (debug_connection)
			NSLog(@"failed to release targets - %@\n", [localException name]);
		}
	NS_ENDHANDLER
}

- (void) retainTarget:(NSUInteger)target
{
	NS_DURING
		{
		if (receive_port && is_valid)
			{
			id ip;			// Tell the remote app that it must retain the
			id result;		// local object for the target on this connection.
			unsigned int i;
			int seq_num = [self _newMsgNumber];
			id op = [_encodingClass newForWritingWithConnection: self
									sequenceNumber: seq_num
									identifier: PROXY_RETAIN];

			[op encodeValueOfCType: @encode(typeof(target))
				at: &target
				withName: NULL];
	
			[op dismiss];
			ip = [self _getReceivedReplyRmcWithSequenceNumber: seq_num];
			[ip decodeObjectAt: &result withName: NULL];
			if (result != nil)
				NSLog(@"failed to retain target - %@\n", result);
			[ip dismiss];
		}	}
	NS_HANDLER
		NSLog(@"failed to retain target - %@\n", [localException name]);
	NS_ENDHANDLER
}

- (void) removeProxy:(NSDistantObject*)aProxy
{
	NSUInteger target = (NSUInteger)[aProxy handleForProxy];

	[PROXIES_HASH_GATE lock];						// Don't assert (is_valid);
	NSMapRemove (remote_proxies, UINT2PTR(target));	// thisalso releases aProxy
	[PROXIES_HASH_GATE unlock];
					// Tell the remote application that we have removed our 
					// proxy and it can release it's local object.
	[self _release_targets: &target count: 1];
}

- (NSDistantObject*) proxyForTarget:(NSUInteger)target
{
	NSDistantObject *p;
													// Don't assert (is_valid); 
	[PROXIES_HASH_GATE lock];
	p = NSMapGet (remote_proxies, UINT2PTR(target));
	[PROXIES_HASH_GATE unlock];
	NSParameterAssert(!p || [p connectionForProxy] == self);
	
	return p;
}

- (void) addProxy:(NSDistantObject*)aProxy
{
	NSUInteger target = (NSUInteger)[aProxy handleForProxy];

	NSParameterAssert (is_valid);
	NSParameterAssert(aProxy->isa == [NSDistantObject class]);
	NSParameterAssert([aProxy connectionForProxy] == self);
	[PROXIES_HASH_GATE lock];
	if (NSMapGet (remote_proxies, UINT2PTR(target)))
		{
		[PROXIES_HASH_GATE unlock];
		[NSException raise: NSGenericException
					 format: @"Trying to add the same proxy twice"];
		}
	NSMapInsert (remote_proxies, UINT2PTR(target), aProxy);
	[PROXIES_HASH_GATE unlock];
}

- (id) _includesProxyForTarget:(NSUInteger)target
{
	NSDistantObject	*ret;
													// Don't assert (is_valid); 
	[PROXIES_HASH_GATE lock];
	ret = NSMapGet (remote_proxies, UINT2PTR(target));
	[PROXIES_HASH_GATE unlock];

	return ret;
}

- (NSDistantObject *) includesLocalTarget:(NSUInteger)target
{
	NSDistantObject *ret;
													// Don't assert (is_valid); 
	[PROXIES_HASH_GATE lock];
	ret = NSMapGet(local_targets, UINT2PTR(target));
	[PROXIES_HASH_GATE unlock];
	
	return ret;
}

/*
	Check all connections.

	Proxy needs to use this when decoding a local object in order to
	make sure the target address is a valid object.  It is not enough
	for the Proxy to check the Proxy's connection only (using
	-includesLocalTarget), because the proxy may have come from a
	triangle connection.
*/
+ (NSDistantObject *) includesLocalTarget:(NSUInteger)target
{
	id ret;
													// Don't assert (is_valid); 
	NSParameterAssert (all_connections_local_targets);
	[PROXIES_HASH_GATE lock];
	ret = NSMapGet (all_connections_local_targets, UINT2PTR(target));
	[PROXIES_HASH_GATE unlock];
	
	return ret;
}
							// Pass nil to remove any reference keyed by aPort.
+ (void) setRootObject:anObj forInPort:(NSPort*)aPort
{
	id oldRootObject = [self rootObjectForInPort: aPort];

	NSParameterAssert ([aPort isValid]);
	if (oldRootObject != anObj)		// This retains aPort?  How will aPort ever 
		{							// get dealloc'ed?
		if (anObj)
			{
			[root_object_dictionary_gate lock];
			[root_object_dictionary setObject: anObj forKey: aPort];
			[root_object_dictionary_gate unlock];
			}
		else						// anObj == nil && oldRootObject != nil
			{
			[root_object_dictionary_gate lock];
			[root_object_dictionary removeObjectForKey: aPort];
			[root_object_dictionary_gate unlock];
		}	}
}

+ rootObjectForInPort:(NSPort*)aPort
{
	id ro;

	[root_object_dictionary_gate lock];
	ro = [root_object_dictionary objectForKey:aPort];
	[root_object_dictionary_gate unlock];
	
	return ro;
}

- (Class) receivePortClass					{ return receive_port_class; }
- (Class) sendPortClass						{ return send_port_class; }
- (Class) encodingClass						{ return _encodingClass; }

- (void) setReceivePortClass:(Class)aPortClass
{
	receive_port_class = aPortClass;
}

- (void) setSendPortClass:(Class)aPortClass
{
	send_port_class = aPortClass;
}

- (NSUInteger) _encoderCreateReferenceForConstPtr:(const void*)ptr
{
	NSUInteger xref;			// Support for cross-connection const-ptr cache

	NSParameterAssert (is_valid);
			// This must match the assignment of xref in _decoderCreateRef...
	xref = NSCountMapTable (outgoing_const_ptr_2_xref) + 1;
	NSParameterAssert(! NSMapGet (outgoing_const_ptr_2_xref, UINT2PTR(xref)));
	NSMapInsert (outgoing_const_ptr_2_xref, ptr, UINT2PTR(xref));
	
	return xref;
}

- (NSUInteger) _encoderReferenceForConstPtr:(const void*)ptr
{
	NSParameterAssert (is_valid);
	return PTR2UINT( NSMapGet (outgoing_const_ptr_2_xref, ptr));
}

- (NSUInteger) _decoderCreateReferenceForConstPtr:(const void*)ptr
{
	NSUInteger xref;

	NSParameterAssert (is_valid);
			// This must match the assignment of xref in _encoderCreateRef...
	xref = NSCountMapTable (incoming_xref_2_const_ptr) + 1;
	NSMapInsert (incoming_xref_2_const_ptr, UINT2PTR(xref), ptr);

	return xref;
}

- (const void*) _decoderConstPtrAtReference:(NSUInteger)xref
{
	NSParameterAssert (is_valid);
	return NSMapGet(incoming_xref_2_const_ptr, UINT2PTR(xref));
}
							// Prevent trying to encode the connection itself 
- (void) encodeWithCoder:anEncoder
{
	[self shouldNotImplement:_cmd];
}

+ newWithCoder:aDecoder
{
	[self shouldNotImplement:_cmd];
	return self;
}
											// Shutting down and deallocating.
			// We register this method for a notification when a port dies.
			// It is possible that the death of a port could be notified
			// to us after we are invalidated in which case we must ignore it.
- (void) portIsInvalid:notification
{
    if (is_valid) 
		{
		id port = [notification object];

		if (debug_connection)
			NSLog(@"Received port invalidation notification for "
					@"connection 0x%x\n\t%@\n", self, [port description]);

		// We shouldn't be getting any port invalidation notifications, except
		// from our own ports; this is how we registered ourselves with the
		// NSNotificationCenter in +newForInPort:outPort:ancestorConnection.
		NSParameterAssert (port == receive_port || port == send_port);

		[self invalidate];
		}
}

@end  /* NSConnection (mGSTEPExtensions) */
