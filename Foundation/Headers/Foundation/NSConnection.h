/*
   NSConnection.h

   Manage connections between DO connected objects

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   GNUstep:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSConnection
#define _mGSTEP_H_NSConnection

#include <Foundation/NSObject.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSMapTable.h>

#define CONNECTION_TIMEOUT   10.0						// in seconds

@class NSDictionary;
@class NSMutableArray;
@class NSString;
@class NSRunLoop;
@class NSDistantObject;
@class NSPort;
@class NSData;

		//	Keys for the NSDictionary returned by [NSConnection -statistics]
extern NSString *NSConnectionRepliesReceived;			// OPENSTEP 4.2
extern NSString *NSConnectionRepliesSent;
extern NSString *NSConnectionRequestsReceived;
extern NSString *NSConnectionRequestsSent;
														// mGSTEP extras
extern NSString *NSConnectionLocalCount;				// Objects sent out
extern NSString *NSConnectionProxyCount;				// Objects received

		// NSRunLoop mode, NSNotification name and NSException strings.
extern NSString	*NSConnectionReplyMode;
extern NSString *NSConnectionDidDieNotification;
extern NSString *NSConnectionDidInitializeNotification;	// OPENSTEP


@interface NSConnection : NSObject
{
	BOOL is_valid;
	BOOL independant_queueing;
	unsigned reply_depth;
	NSPort *receive_port;
	NSPort *send_port;
	unsigned message_count;
	unsigned req_out_count;
	unsigned req_in_count;
	unsigned rep_out_count;
	unsigned rep_in_count;
	NSMapTable *local_objects;
	NSMapTable *local_targets;
	NSMapTable *remote_proxies;
	NSTimeInterval reply_timeout;
	NSTimeInterval request_timeout;
	Class receive_port_class;
	Class send_port_class;
	Class _encodingClass;
	NSMapTable *incoming_xref_2_const_ptr;
	NSMapTable *outgoing_const_ptr_2_xref;
	id delegate;
	NSMutableArray *request_modes;

//    id _rootObject;
}

+ (NSConnection*) connectionWithReceivePort:(NSPort*)r sendPort:(NSPort*)s;
+ (NSConnection*) defaultConnection;
+ (NSConnection*) connectionWithRegisteredName:(NSString*)n
                                          host:(NSString*)h;

+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName:(NSString*)n
                                                         host:(NSString*)h;
+ (NSArray*) allConnections;

- (id) initWithReceivePort:(NSPort*)r sendPort:(NSPort*)s;

- (NSPort*) sendPort;
- (NSPort*) receivePort;

- (void) runInNewThread;
- (BOOL) registerName:(NSString*)name;

- (void) addRequestMode:(NSString*)mode;
- (void) removeRequestMode:(NSString*)mode;
- (NSArray*) requestModes;

- (void) enableMultipleThreads;
- (BOOL) multipleThreadsEnabled;
- (BOOL) isValid;
- (void) invalidate;
- (NSArray *) remoteObjects;
- (void) removeRunLoop:(NSRunLoop *)runloop;
- (NSDistantObject*) rootProxy;
- (NSDictionary*) statistics;

- (void) setReplyTimeout:(NSTimeInterval)seconds;
- (void) setRequestTimeout:(NSTimeInterval)seconds;
- (NSTimeInterval) replyTimeout;
- (NSTimeInterval) requestTimeout;

- (BOOL) independentConversationQueueing;
- (void) setIndependentConversationQueueing:(BOOL)flag;

- (id) rootObject;
- (void) setRootObject:(id)anObj;

- (id) delegate;
- (void) setDelegate:(id)anObj;

@end
				//  This catagory contains legacy methods from the original GNU 
				//  'Connection' class, and useful extensions to NSConnection.
@interface NSConnection (mGSTEPExtensions)  //<GCFinalization>

+ (NSConnection*) _connectionWithReceivePort:(NSPort*)ip
									sendPort:(NSPort*)op;
- (void) gcFinalize;

+ (int) messagesReceived;					// Query state of all connections
+ (unsigned) connectionsCount;
+ (unsigned) connectionsCountWithInPort:(NSPort*)aPort;

	// Get a proxy to a remote server obj. New connection is created if needed
+ (NSDistantObject*) rootProxyAtName:(NSString*)name onHost:(NSString*)host;
+ (NSDistantObject*) rootProxyAtName:(NSString*)name;
//+ (NSDistantObject*) rootProxyAtPort:(NSPort*)anOutPort;
//+ (NSDistantObject*) rootProxyAtPort:(NSPort*)anOutPort 
//						  withInPort:(NSPort*)anInPort;

	// Make a connection obj start listening for incoming requests. After DATE.
- (void) runConnectionUntilDate:date;
- (void) runConnection;						// Same as above, but no time out
	
	// For getting the root object of a connection or port
+ rootObjectForInPort:(NSPort*)aPort;

	// Used for setting the root object of a connection that we created without 
	// one, or changing the root object of a connection that already has one.
+ (void) setRootObject:(id)anObj forInPort:(NSPort*)aPort;

- (Class) receivePortClass;
- (Class) sendPortClass;
- (void) setReceivePortClass:(Class)aPortClass;
- (void) setSendPortClass:(Class)aPortClass;

- (void) addProxy:(NSDistantObject*)aProxy;			// Only subclassers and 
- (id) _includesProxyForTarget:(NSUInteger)target;	// power-users need worry 
- (void) removeProxy:(NSDistantObject*)aProxy;		// about these

- (void) addLocalObject:(id)anObj;
- (void) removeLocalObject:(id)anObj;

- (const char *) typeForSelector:(SEL)sel remoteTarget:(NSUInteger)target;
- (NSUInteger) _encoderReferenceForConstPtr:(const void*)ptr;
- (NSUInteger) _encoderCreateReferenceForConstPtr:(const void*)ptr;
- (NSUInteger) _decoderCreateReferenceForConstPtr:(const void*)ptr;
- (const void*) _decoderConstPtrAtReference:(NSUInteger)xref;

@end


enum {
	METHOD_REQUEST = 0,					// DO identifiers. Define the type of 
	METHOD_REPLY,						// messages sent by the D.O. system.
	ROOTPROXY_REQUEST,
	ROOTPROXY_REPLY,
	CONNECTION_SHUTDOWN,
	METHODTYPE_REQUEST,
	METHODTYPE_REPLY,
	PROXY_RELEASE,
	PROXY_RETAIN,
	RETAIN_REPLY
};
		//	Catagory containing the methods by which the public interface to
		//	NSConnection must be extended in order to allow it's use by
		//	by NSDistantObject et al for implementation of Distributed objects.
@interface NSConnection (Internal)

+ (NSConnection*) _connectionByInPort:(NSPort*)ip outPort:(NSPort*)op;
+ (NSConnection*) _connectionByOutPort:(NSPort*)op;
+ (NSDistantObject*) includesLocalTarget:(NSUInteger)target;
- (NSDistantObject*) includesLocalTarget:(NSUInteger)target;
- (NSDistantObject*) localForObject:(id)object;
- (NSDistantObject*) localForTarget:(NSUInteger)target;
- (NSDistantObject*) proxyForTarget:(NSUInteger)target;
- (void) retainTarget:(NSUInteger)target;

@end

#endif /* _mGSTEP_H_NSConnection */
