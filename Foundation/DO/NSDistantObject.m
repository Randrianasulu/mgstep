/*
   NSDistantObject.m

   Class which defines proxies for objects in other applications

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Rewrite: Richard Frith-Macdonald <richard@brainstorm.co.u>

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSDistantObject.h>
#include <Foundation/NSException.h>
#include <Foundation/Protocol.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSMethodSignature.h>

#include "_NSPortCoder.h"

// Class variables
static int debug_proxy = 0;

enum
{										// This is the proxy tag; it indicates 
	PROXY_LOCAL_FOR_RECEIVER = 0,		// where the local object is, and 
	PROXY_LOCAL_FOR_SENDER,				// determines whether the reply port to 
	PROXY_REMOTE_FOR_BOTH				// the <Connection where the proxy is 
};										// local> needs to be encoded/decoded 
										// or not

@implementation NSDistantObject

+ (NSDistantObject*) proxyWithLocal:(id)obj connection:(NSConnection*)c
{
	NSDistantObject *proxy;

	NSAssert([c isValid], NSInternalInconsistencyException);
			// If there already is a local proxy for this target/connection
			// combination, don't create a new one, just return the old one.
	if ((proxy = [c localForObject: obj]))
		return [proxy retain];

	return [[[self alloc] initWithLocal:obj connection:c] autorelease];
}

+ (NSDistantObject*) proxyWithTarget:(NSUInteger)target connection:(NSConnection*)c
{
	NSDistantObject	*proxy;

	NSAssert([c isValid], NSInternalInconsistencyException);

				// If there already is a local proxy for this target/connection
				// combination, don't create a new one, just return old one.
	if ((proxy = [c proxyForTarget: target]))
		return [proxy retain];

	return [[[self alloc] initWithTarget:target connection:c] autorelease];
}

- (id) initWithLocal:(id)anObject connection:(NSConnection*)aConnection
{
	NSDistantObject *proxy;

	NSAssert([aConnection isValid], NSInternalInconsistencyException);

	if ((proxy = [aConnection localForObject: anObject]))
		{							// If there already is a local proxy for
		[self release];				// this target/connection combo, don't
		return [proxy retain];		// create a new one, return the old one
		}
			// We don't need to retain the object here - the connection
			// will retain the proxies local object if necessary (and 
			// release it when all proxies referring to it have been released).
	_local = anObject;
						// We register this proxy with the connection using it.
	_connection = [aConnection retain];
	[_connection addLocalObject: self];

	if (debug_proxy)
	 NSLog(@"Created new local=0x%x object 0x%x handle 0x%x connection 0x%x\n",
			self, _local, _handle, _connection);

	return self;
}

- (id) initWithTarget:(NSUInteger)target connection:(NSConnection*)aConnection
{
	NSDistantObject *proxy;

	NSAssert([aConnection isValid], NSInternalInconsistencyException);

	if ((proxy = [aConnection proxyForTarget: target]))
		{							// If there already is a local proxy for
		[self release];				// this target/connection combo, don't
		return [proxy retain];		// create a new one, return the old one
		}

	_local = nil;
	_handle = target;
					// We retain our connection so it can't disappear 
					// while the app may want to use it.
	_connection = [aConnection retain];

					// We register this object with the connection using it.
	[_connection addProxy: self];

	if (debug_proxy)
		NSLog(@"Created new proxy=0x%x handle 0x%x connection 0x%x\n",
				self, _handle, _connection);

	return self;
}

- (void) dealloc
{
	[self gcFinalize];
	[super dealloc];
}

- (void) setProtocolForProxy:(Protocol*)aProtocol	{ _protocol = aProtocol; }
- (NSConnection*) connectionForProxy				{ return _connection; }

- (void) forwardInvocation:(NSInvocation*)anInvocation
{
	[_connection forwardInvocation: anInvocation];
}

- (NSMethodSignature*) methodSignatureForSelector:(SEL)aSelector
{
	if (_local)
		return [_local methodSignatureForSelector: aSelector];

	if (_protocol)
		{
		const char *types = 0;
		struct objc_method_description* mth;
	
		if ((mth = [_protocol descriptionForInstanceMethod: aSelector]) == 0)
			mth = [_protocol descriptionForClassMethod: aSelector];

		if (mth != 0)
			types = mth->types;

		if (types == 0)
			return nil;

		return [NSMethodSignature signatureWithObjCTypes: types];
		}
}

- (void) encodeWithCoder:(NSCoder*)aRmc
{
	NSUInteger proxy_target;
	unsigned char proxy_tag;
	NSConnection *encoder_connection;

	if ([aRmc class] != [PortEncoder class])
		[NSException raise: NSGenericException
					 format: @"NSDistantObject objects only "
							@"encode with PortEncoder class"];

	encoder_connection = [(NSPortCoder*)aRmc connection];
	NSAssert(encoder_connection, NSInternalInconsistencyException);

	if (![encoder_connection isValid])
		[NSException raise: NSGenericException
			format: @"Trying to encode to an invalid Connection.\n"
			@"You should request NSConnectionDidDieNotification's and\n"
			@"release all references to the proxy's of invalid Connections."];

	proxy_target = _handle;

	if (encoder_connection == _connection)
		{
		if (_local)
			{			// This proxy is a local to us, remote to other side.
			proxy_tag = PROXY_LOCAL_FOR_SENDER;

			if (debug_proxy)
			   NSLog(@"Sending a proxy, will be remote 0x%x connection 0x%x\n",
					proxy_target, _connection);

			[(NSCoder <Encoding>*)aRmc 
					encodeValueOfCType: @encode(typeof(proxy_tag))
					at: &proxy_tag
					withName: @"Proxy is local for sender"];

			[(NSCoder <Encoding>*)aRmc 
					encodeValueOfCType: @encode(NSUInteger)
					at: &proxy_target
					withName: @"Proxy target"];
			}
		else
			{				// This proxy is a local object on the other side.
			proxy_tag = PROXY_LOCAL_FOR_RECEIVER;

			if (debug_proxy)
				NSLog(@"Sending a proxy, will be local 0x%x connection 0x%x\n",
						proxy_target, _connection);

			[(NSCoder <Encoding>*)aRmc 
					encodeValueOfCType: @encode(typeof(proxy_tag))
					at: &proxy_tag
					withName: @"Proxy is local for receiver"];

			[(NSCoder <Encoding>*)aRmc 
					encodeValueOfCType: @encode(NSUInteger)
					at: &proxy_target
					withName: @"Proxy target"];
			}
		}
	else
		{				// This proxy will still be remote on the other side
		NSPort *proxy_connection_out_port = [_connection sendPort];
		NSDistantObject *localProxy;

		NSAssert(proxy_connection_out_port, NSInternalInconsistencyException);
		NSAssert([proxy_connection_out_port isValid],
				 NSInternalInconsistencyException);
		NSAssert(proxy_connection_out_port != [encoder_connection sendPort],
				 NSInternalInconsistencyException);

		proxy_tag = PROXY_REMOTE_FOR_BOTH;

				// Get a proxy to refer to self - we send this to the other
				// side so we will be retained until the other side has
				// obtained a proxy to the original object via a connection
				// to the original vendor.
		localProxy = [NSDistantObject proxyWithLocal: self
									  connection: encoder_connection];

		if (debug_proxy)
			NSLog(@"Sending triangle-connection proxy 0x%x "
					@"proxy-conn 0x%x to-proxy 0x%x to-conn 0x%x\n",
					localProxy->_handle, localProxy->_connection,
					proxy_target, _connection);

							// It's remote here, so we need to tell other side 
							// where to form triangle connection to
		[(NSCoder <Encoding>*)aRmc 
			  encodeValueOfCType:@encode(typeof(proxy_tag))
			  at: &proxy_tag
		      withName: @"Proxy remote for both sender and receiver"];

		[(NSCoder <Encoding>*)aRmc 
			  encodeValueOfCType:@encode(typeof(localProxy->_handle))
			  at: &localProxy->_handle
		      withName: @"Intermediary target"];

		[(NSCoder <Encoding>*)aRmc 
			  encodeValueOfCType: @encode(NSUInteger)
			  at: &proxy_target
		      withName: @"Original target"];

		[(NSCoder <Encoding>*)aRmc encodeBycopyObject:proxy_connection_out_port
								   withName: @"Original port"];
		}
}

- (id) initWithCoder:(NSCoder*)aCoder
{
	unsigned char proxy_tag;
	NSUInteger target;
	id decoder_connection;

	if ([aCoder class] != [PortDecoder class])
		{
		[self release];
		[NSException raise: NSGenericException
					 format: @"NSDistantObject objects only decode with "
							 @"PortDecoder class"];
		}

	decoder_connection = [(NSPortCoder*)aCoder connection];
	NSAssert(decoder_connection, NSInternalInconsistencyException);

				// First get the tag, so we know what values need to be decoded
	[(NSCoder <Decoding>*)aCoder decodeValueOfCType: @encode(typeof(proxy_tag))
								 at: &proxy_tag
								 withName: NULL];
	switch (proxy_tag)
		{
		case PROXY_LOCAL_FOR_RECEIVER:
					// This was a proxy on the other side of the connection,
					// but here it's local.  Lookup the target handle to ensure 
					// that it exists here.  Return a retained copy of the 
					// local target object.
			[(NSCoder <Decoding>*)aCoder
						decodeValueOfCType:@encode(typeof(target))
						at: &target
						withName: NULL];

			if (debug_proxy)
				NSLog(@"Receiving a proxy for local object 0x%x "
					  @"connection 0x%x\n",target, decoder_connection);

			if (![[decoder_connection class] includesLocalTarget: target])
				{
				[self release];
				[NSException raise: @"ProxyDecodedBadTarget"
						format: @"No local object with given target (0x%x)",
								target];
				}
			else
				{
				NSDistantObject	*o;
		
				o = [decoder_connection includesLocalTarget: target];
				if (debug_proxy)
					NSLog(@"Local object is 0x%x (0x%x)\n",
							o, o ? o->_local : 0);
				[self release];

				return o ? [o->_local retain] : nil;
				}

		case PROXY_LOCAL_FOR_SENDER:
				// This was a local object on the other side of the connection,
				// but here it's a proxy object.  Get the target address, and
				// send [NSDistantObject +proxyWithTarget:connection:]; this
				// will return the proxy object we already created for this 
				// target, or create a new proxy object if necessary.
			[(NSCoder <Decoding>*)aCoder 
					decodeValueOfCType: @encode(typeof(target))
					at: &target
					withName: NULL];
			if (debug_proxy)
				NSLog(@"Receiving a proxy, was local 0x%x connection 0x%x\n",
						target, decoder_connection);
			[self release];

			return [[NSDistantObject proxyWithTarget: target
									 connection: decoder_connection] retain];

		case PROXY_REMOTE_FOR_BOTH:
			// This was a proxy on the other side of the connection, and it
			// will be a proxy on this side too; that is, the local version
			// of this object is not on this host, not on the host the
			// NSPortCoder is connected to, but on a *third* host.
			// This is why I call this a "triangle connection".  In addition
			// to decoding the target, we decode the OutPort object that we
			// will use to talk directly to this third host.  We send
			// [NSConnection +newForInPort:outPort:ancestorConnection:]; this
			// will either return the connection already created for this
			// inPort/outPort pair, or create a new connection if necessary.
			{
			NSDistantObject	*result;
			NSConnection *proxy_connection;
			NSPort *proxy_connection_out_port = nil;
			NSUInteger intermediary;

				// There is an object on the intermediary host that is keeping
				// that hosts proxy for the original object retained, thus
				// ensuring that the original is not released.  We create a
				// proxy for that intermediate proxy.  When we release this
				// proxy, the intermediary will be free to release it's proxy
				// and the original can then be released.  Of course, by that
				// time we will have obtained our own proxy for the orig object
			[(NSCoder <Decoding>*)aCoder 
					decodeValueOfCType: @encode(typeof(intermediary))
					at: &intermediary
					withName: NULL];
			[NSDistantObject proxyWithTarget: intermediary
							 connection: decoder_connection];

				// Now we get the target number and port for the orignal object
				// and (if necessary) get the originating process to retain the
				// object for us.
			[(NSCoder <Decoding>*)aCoder 
					decodeValueOfCType: @encode(typeof(target))
					at: &target
					withName: NULL];
	
			[(NSCoder <Decoding>*)aCoder 
					decodeObjectAt: &proxy_connection_out_port
					withName: NULL];
	
			NSAssert(proxy_connection_out_port, 
					NSInternalInconsistencyException);
				// If there already exists a connection for talking to the out 
				// port, we use that one rather than creating a new one from
				// our listening port.  First we try for a connection from our 
				// receive port, Then we try any connection to the send port
				// Finally we resort to creating a new connection - we don't
				// release the newly created connection - it will get released
				// automatically when no proxies are left on it.
			proxy_connection = [[decoder_connection class]
						_connectionByInPort: [decoder_connection receivePort]
						outPort: proxy_connection_out_port];
			if (proxy_connection == nil)
				{
				proxy_connection = [[decoder_connection class]
						_connectionByOutPort: proxy_connection_out_port];
				}
			if (proxy_connection == nil)
				{
				proxy_connection = [[decoder_connection class]
					_connectionWithReceivePort:[decoder_connection receivePort]
					sendPort: proxy_connection_out_port];
				[proxy_connection autorelease];
				}
	
			if (debug_proxy)
				NSLog(@"Receiving a triangle-connection proxy 0x%x "
					  @"connection 0x%x\n", target, proxy_connection);
	
			NSAssert(proxy_connection != decoder_connection,
			NSInternalInconsistencyException);
			NSAssert([proxy_connection isValid],
			NSInternalInconsistencyException);
	
				//	If we don't already have a proxy for the object on the
				//	remote system, we must tell the other end to retain its
				//	local object for our use.
			if ([proxy_connection _includesProxyForTarget: target] == NO)
				[proxy_connection retainTarget: target];
	
			result = [[NSDistantObject proxyWithTarget: target
									   connection: proxy_connection] retain];
			[self release];
				//	Finally - we have a proxy via a direct connection to the
				//	originating server.  We have also created a proxy to an
				//	intermediate object - but this proxy has not been retained
				//	and will therefore go away when the current autorelease
				//	pool is destroyed.
			return result;
			}

		default:		// FIX ME s/b something other than NSGenericException.
			[self release];
			[NSException raise: NSGenericException format: @"Bad proxy tag"];
		}

	return nil;													// Not reached
}

@end  /* NSDistantObject */


@implementation NSDistantObject (mGSTEPExtensions)

+ (void) _setDebug:(int)val			{ debug_proxy = val; }

- (void) gcFinalize
{
	if (_connection)
		{
		if (debug_proxy > 3)
			NSLog(@"retain count for connection (0x%x) is now %u\n",
					_connection, [_connection retainCount]);
			// A proxy for local object does not retain it's target - the
			// NSConnection class does that for us - so we need not release it.
			// For a local object the connection also retains this proxy, so we
			// can't be deallocated unless we are already removed from the
			// connection.

			// A proxy retains it's connection so that the connection will
			// continue to exist as long as there is a something to use it.
			// So we release our reference to the connection here just as soon
			// as we have removed ourself from the connection.
		if (_local == nil)
			[_connection removeProxy: self];
		[_connection release];
		}
}

- (Class) classForCoder					 { return object_get_class (self); }
- (Class) classForPortCoder				 { return object_get_class (self); }

- (id) replacementObjectForCoder:(NSCoder*)aCoder			{ return self; }
- (id) replacementObjectForPortCoder:(NSPortCoder*)aCoder	{ return self; }
- (id) awakeAfterUsingCoder:(NSCoder*)aDecoder				{ return self; }

@end  /* NSDistantObject (mGSTEPExtensions) */


@implementation NSObject (NSDistributedObjects)

- (Class) classForPortCoder					{ return [self classForCoder]; }

- (id) replacementObjectForPortCoder:(NSPortCoder*)coder
{
	if ([coder isBycopy]) 
		return self;

	return [NSDistantObject proxyWithLocal:self connection:[coder connection]];
}

@end


@implementation Protocol (DistributedObjectsCoding)

- (Class) classForPortCoder					{  return [self class]; }

- (id) replacementObjectForPortCoder:(NSPortCoder*)coder
{
	if ([coder isBycopy])
		return self;

	return [NSDistantObject proxyWithLocal:self connection:[coder connection]];
}

@end
