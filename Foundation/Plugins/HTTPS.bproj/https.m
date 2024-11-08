/*
   https.m

   Copyright (C) 2020 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	November 2020

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSURL.h>
#include <Foundation/NSURLCredential.h>
#include <Foundation/NSString.h>
#include <Foundation/NSData.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSError.h>

#include <Security/Security.h>

extern NSString *SSLErrorDomain;


@interface _NSURLProtocolHTTPS : NSURLProtocol
{
	SSLContextRef _context;
	SecTrustRef   _trust;
	BOOL _handshake;
}
@end

@interface NSURLProtocol  (responder)
- (BOOL) _respondWithHTTP:(NSMutableData *)mdata;
@end

@interface NSMutableData  (_NSDataDecompressGZ)
- (id) decompressGZ;
@end


@implementation _NSURLProtocolHTTPS

+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
	return [[[request URL] scheme] isEqualToString: @"https"];
}

- (void) dealloc
{
	if (_context)
		CFRelease(_context),	_context = NULL;
	if (_trust)
		CFRelease(_trust),		_trust = NULL;

	[super dealloc];
}

- (void) useCredential:(NSURLCredential *)credential
		 forAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch
{
	_up.authenticated = YES;
}

- (void) continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch
{
	_up.authenticated = YES;
}

- (void) cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch
{
	SSLClose(_context);
}

- (void) _receivedEvent:(void*)delegate					// called by Connection
				   type:(CFSocketCallBackType)type		// when select() says
				   extra:(const void*)extra				// the fd is ready
{
	int read_data = 0;
	char buf[3584];
	size_t size;
	OSStatus r;

	DBLog(@"_NSURLProtocolHTTPS _receivedEvent");
	if (!_context)
		{						// have TCP connection, perform SSL handshake
		_context = SSLCreateContext(NULL, kSSLClientSide, kSSLStreamType);
		SSLSetConnection(_context, (SSLConnectionRef)extra);
		}

	if (!_handshake)										// kSSLHandshake
		{
		if (SSLHandshake(_context) == 0)
			{
    		SecTrustResultType tr = kSecTrustResultInvalid;

				// set flag to allow expired certificates
//			SecTrustSetOptions(peerTrust, kSecTrustOptionAllowExpired);

			if (SSLCopyPeerTrust (_context, &_trust) == errSecSuccess)
				SecTrustEvaluate(_trust, &tr);

			if (tr == kSecTrustResultProceed)
				_handshake = _up.authenticated = YES;		// kSSLConnected
			else if (tr == kSecTrustResultUnspecified)
				_handshake = YES;							// kSSLConnected
			else
				{
//				if (tr == kSecTrustResultRecoverableTrustFailure)
//					{} // not trusted, but recoverable, ask user
				NSLog(@"*** URL Protocol Trust Failure: %d", tr);
				SSLClose(_context);
				return;
				}
			}
		else
			return;
		}

// https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/OverridingSSLChainValidationCorrectly.html
	if (!_up.authenticated)
		{
		SEL sel = @selector(connection:canAuthenticateAgainstProtectionSpace:);

		if ([(id)delegate respondsToSelector: sel])
			{
			NSURLProtectionSpace *ps = (NSURLProtectionSpace *) _context;
			id <NSURLConnectionDelegate> d = delegate;
							// ps auth is NSURLAuthenticationMethodServerTrust
			if ([d connection:_client canAuthenticateAgainstProtectionSpace:ps])
				{			// a credential based on certs the server provided
				NSURLCredential *cd = [NSURLCredential credentialForTrust:_trust];
				NSURLAuthenticationChallenge *ch = [NSURLAuthenticationChallenge alloc];

				ch = [ch initWithProtectionSpace:ps
						 proposedCredential:cd
						 previousFailureCount:0
						 failureResponse:nil
						 error:nil
						 sender:(id <NSURLAuthenticationChallengeSender>)self];

				[d connection:_client didReceiveAuthenticationChallenge:ch];
			}	}
		else
			{
			NSLog(@"*** URL Protocol Trust Failure (delegate): %d", -1);
			SSLClose(_context);
			return;
		}	}

	if (!_up.queried)
		{
		_up.queried = YES;
///		printf ("SSL query string:\n%s", [_header cString]);

		if ((r = SSLWrite (_context, [_header cString], [_header length], &size)) != 0)
			if (r != errSSLWouldBlock)
				{
				id <NSURLConnectionDelegate> d = delegate;
				NSError *e = _NSError(SSLErrorDomain, r, @"SSL write error");

				NSLog(@"URL: error writing to SSL socket (%d)\n", r);
				[d connection:_client didFailWithError:e];
				}

		return;
		}

	if (!_data)
		_data = [NSMutableData new];

	for (; !(r = SSLRead (_context, buf, 3584, &size)) && size > 0; read_data++)
		[_data appendBytes:buf length:size];

	if (read_data)
		{
		NSLog(@"URL: SSLRead data %lu\n", [_data length]);
		if (!_up.responded && ![self _respondWithHTTP:_data])
			return;

		if (_up.gzip && [_data length] >= _length)
			if ((_data = [[_data autorelease] decompressGZ]))
				_up.decompressed = YES;

		if (!_up.gzip || _up.decompressed)
			{
			[_client URLProtocol:self didLoadData:_data];
			[_data setLength: 0];
		}	}

	if (r < 0 && r != errSSLWouldBlock && errno != EAGAIN && errno != 0)
		{
		NSLog(@"URL: Error in read() %d - %s\n", errno, strerror(errno));
		[_client URLProtocol:self didFailWithError:nil];
		}
	else
		{
		DBLog(@"URL: NSURLProtocol read %lu\n", size);
		if (r != errSSLWouldBlock && size == 0)
			{
			NSLog(@"URL: NSURLProtocol complete\n");
			[_client URLProtocolDidFinishLoading: self];
			}
		}
}

@end
