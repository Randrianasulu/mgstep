/*
   NSURL.m

   URL loading classes

   Copyright (C) 2004-2020 Free Software Foundation, Inc.

   mySTEP:  Dr. H. Nikolaus Schaller
   Date: 	Jan 2004-2006
   mGSTEP:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	Sep 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSURL.h>
#include <Foundation/NSURLCredential.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSError.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHost.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/Private/_NSURL.h>

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRunLoop.h>
#include <CoreFoundation/CFSocket.h>

#include <ctype.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define STR_RANGE(x)  (x.location) ? [_urlString substringWithRange: x] : nil;


typedef struct { @defs(NSURLConnection); } _NSURLConnection;


NSString *SSLErrorDomain = @"OpenSSLErrorDomain";	// @"mbedTLS ErrorDomain"

NSString *NSErrorFailingURLStringKey = @"NSErrorFailingURLStringKey";
NSString *NSURLErrorKey              = @"NSURLErrorKey";

NSString *NSURLAuthenticationMethodDefault           = @"DefaultAuth";
NSString *NSURLAuthenticationMethodClientCertificate = @"ClientCert";
NSString *NSURLAuthenticationMethodServerTrust       = @"ServerTrust";

static NSMutableArray *__registeredURLProtocols = nil;
static NSString *__content = @"Accept: */*\r\nAccept-Encoding: identity\r\n";
static Class __gzPlugin = Nil;

struct _schemeItem { NSString *scheme; char *prefix; int port; };

static struct _schemeItem __stable[] = {{ @"http",  "http:",   80},
										{ @"https", "https:",  443},
										{ @"data",  "data:",   0},
										{ @"file",  "file:",   0},
										{ @"ftp",   "ftp:",    21} };

#define SCHEME_TABLE_SIZE  (sizeof(__stable) / sizeof(struct _schemeItem))

extern NSMutableData * _NSDataDecompressGZ(NSData *source);

/* ****************************************************************************

	NSURL

** ***************************************************************************/

@implementation NSURL

+ (id) URLWithString:(NSString *)urlString
{
	return [[[self alloc] initWithString:urlString] autorelease];
}

+ (id) URLWithString:(NSString *)urlString relativeToURL:(NSURL *)baseURL
{
	return [[[self alloc] initWithString:urlString
						  relativeToURL:baseURL] autorelease];
}

+ (id) fileURLWithPath:(NSString *)path
{
	return [[[self alloc] initFileURLWithPath: path] autorelease];
}

- (id) initFileURLWithPath:(NSString *)path
{
	_urlString = [[NSString stringWithFormat: @"file://%@", path] retain];
	_path = [path retain];
	_scheme = @"file";

	return self;
}

- (id) initWithString:(NSString *)urlString relativeToURL:(NSURL *)baseUrl
{
	_baseURL = (baseUrl && !baseUrl->_scheme) ? [[baseUrl absoluteURL] retain]
											  : [baseUrl retain];
	return [self initWithString: urlString];
}

- (id) initWithString:(NSString *)urlString
{
	const char *s = [urlString cString];
	const char *ep = s + strlen(s);
	const char *p = s;
	char buf[1024] = {0};
	int i, j;

	if (strlen(s) < 5)
		return _NSInitError(self, @"malformed URL string: %@", urlString);

	for (i = 0; i < SCHEME_TABLE_SIZE; i++)
		if (!strncasecmp(s, __stable[i].prefix, strlen(__stable[i].prefix)))
			{
			p = s + strlen(__stable[i].prefix);
			_scheme = __stable[i].scheme;
			_port   = __stable[i].port;
			break;
			}

	if (!_scheme && isALPHA(*s))
		for (p = s; p < ep && *p != ':' && isSCHEME(*p); p++);

	if (*p == ':')										// non-std absolute URL
		{
		strncpy(buf, s, MIN(1023, p - s));
		_scheme = [[NSString stringWithCString:buf] retain];
		p++;
		}
	else if (p >= ep || (!_scheme && !_baseURL))		// ran off end of URL
		return _NSInitError(self, @"malformed URL string: %@", urlString);

	_resource = (NSRange){p-s, ep-p};		// resource str after ':'

	if (*p != '/')							// data: scheme or relative URL
		_host = @"localhost";				// data:text/html;charset=utf-8,ASF
	if (*p == '/' && *(p+1) == '/')
		{									// network and auth
		ep = p += 2;						// user:password@host:port/

		for (i = 0; *ep && *ep != '/' && *ep != '@'; ep++, i++);

		if (*ep == '@')								// found basic auth
			{
			char user[256] = {0};
			char pass[256] = {0};
			const char *e = p;

			for (j = 0; *e && *e != '@' && *e != ':'; e++, j++);

			if (j < 1 || j > 255)
				return _NSInitError(self, @"URL user name length not (1-255)");

			strncpy(user, p, j);
			_user = [[NSString stringWithCString:user] retain];

			if (*e == ':')							// has password
				{
				i -= j + 1;
				if (i < 1 || i > 255)
					return _NSInitError(self, @"URL pwd length not (1-255)");
				strncpy(pass, ++e, i);
				_password = [[NSString stringWithCString:pass] retain];
				}

			p = ++ep;								// point to host
			}

		if (*p == '[')								// ipv6 host
			for (i = 0, ep = ++p; *ep && *ep != '/' && *ep != ']'; ep++, i++);
		else										// port or end of network
			for (i = 0, ep = p; *ep && *ep != '/' && *ep != ':'; ep++, i++);

		if (i < 1 || i > 1024)
			return _NSInitError(self, @"malformed host name in URL string");

		memset(buf, 0, sizeof(buf));
		strncpy(buf, p, MIN(i, 1023));
		_host = [[NSString stringWithCString:buf] retain];

		if (*ep == ']')									// ipv6 port number
			for (; *ep && *ep != '/' && *ep != ':'; ep++);

		if (*ep == ':')									// port number
			{
			for (i = 0, p = ++ep; *ep && *ep != '/' && i < 8; ep++, i++);

			if (i < 1 || i > 6)
				return _NSInitError(self, @"malformed port number in URL string");

			memset(buf, 0, sizeof(buf));
			strncpy(buf, p, i);
			_port = atoi(buf);
			}
		p = ep;
		}

	for (; *ep && *ep != ';' && *ep != '?' && *ep != '#'; ep++);	// path

	if (ep - p > 1024)
		return _NSInitError(self, @"malformed path in URL string");

	if (ep - p > 0)
		{
		memset(buf, 0, sizeof(buf));
		strncpy(buf, p, MIN(ep - p, 1023));
		_path = [[NSString stringWithCString:buf] retain];
		}
	else
		_path = @"/";

	if (*ep == ';')											// parameters
		{
		for (i = 0, p = ++ep; *ep && *ep != '?'; ep++, i++);
		_parameter = (NSRange){p-s, i};
		}

	if (*ep == '?')											// query
		{
		for (i = 0, p = ++ep; *ep && *ep != '#'; ep++, i++);
		_query = (NSRange){p-s, i};
		}

	if (*ep == '#')											// fragment
		{
		for (i = 0, p = ++ep; *ep; ep++, i++);
		_fragment = (NSRange){p-s, i};
		}

	_urlString = [urlString retain];

	return self;
}

- (id) copy							{ return [self retain]; }

- (NSString *) host					{ return _host; }
- (NSString *) user					{ return _user; }
- (NSString *) password				{ return _password; }
- (NSString *) path					{ return _path; }
- (NSNumber *) port					{ return [NSNumber numberWithInt: _port]; }
- (NSString *) scheme				{ return _scheme; }
- (NSString *) query				{ return STR_RANGE(_query); }
- (NSString *) relativePath			{ return [_baseURL path]; }
- (NSString *) relativeString		{ return [_baseURL absoluteString]; }
- (NSString *) fragment				{ return STR_RANGE(_fragment); }
- (NSString *) lastPathComponent	{ return [_path lastPathComponent];}
- (NSString *) pathExtension		{ return [_path pathExtension]; }
- (NSString *) parameterString		{ return STR_RANGE(_parameter); }
- (NSString *) resourceSpecifier	{ return STR_RANGE(_resource); }

- (NSURL *) baseURL					{ return _baseURL; }

- (NSURL *) absoluteURL
{
	return (_baseURL) ? [NSURL URLWithString:[self absoluteString]] : self;
}

- (NSString *) absoluteString
{
	if (!_baseURL)
		return _urlString;

	return [_baseURL->_urlString stringByAppendingPathComponent:_urlString];
}

- (void) dealloc
{
	[_host release],		_host = nil;
	[_hostIP release],		_hostIP = nil;
	[_path release],		_path = nil;
	[_urlString release],	_urlString = nil;
	[_baseURL release],		_baseURL = nil;
	[_password release],	_password = nil;
	[_user release],		_user = nil;

	[super dealloc];
}

- (BOOL) isEqual:(id)other
{
	if (self == other)
		return YES;
	if (other == nil || ![other isKindOfClass:[NSURL class]])
		return NO;
	if ((_baseURL == nil) != (((NSURL *)other)->_baseURL == nil))
		return NO;
	if ((_baseURL == nil))
		return [_urlString isEqualToString: ((NSURL *)other)->_urlString];
	return [_baseURL->_urlString isEqualToString: ((NSURL*)other)->_baseURL->_urlString]
				&& [_urlString isEqualToString: ((NSURL *)other)->_urlString];
}

- (NSUInteger) hash
{
	return _hash ? _hash : (_hash = [[self absoluteString] hash]);
}

- (NSString *) description
{
	if (!_urlString)
		return [super description];

	return (!_baseURL) ? _urlString : [NSString stringWithFormat:@"%@ ++ %@",
										_baseURL->_urlString, _urlString];
}

- (BOOL) isFileURL							{ return (_scheme == @"file"); }

- (BOOL) getFileSystemRepresentation:(char*)buffer maxLength:(NSUInteger)size
{
	return [_path getFileSystemRepresentation:buffer maxLength:size];
}

- (const char *) fileSystemRepresentation
{
	return [_path fileSystemRepresentation];
}

- (NSData *) _socketAddress
{
	struct {  struct sockaddr_in  sa;
			  struct sockaddr_in6 sa6; } u;
	const char *cs, *p;
	int addrlen;
	int r;

	if (!_hostIP)
		{
		const char *h = [_host cString];
		BOOL isAddress = (BOOL)isxdigit(*h) || *h == ':';
		NSHost *t = isAddress ? [NSHost hostWithAddress: _host]
							  : [NSHost hostWithName:    _host];

		if (!(_hostIP = [[t address] retain]))
			return _NSLogError(@"URL has no host IP address");
		}

	memset(&u, 0, sizeof u);
	cs = [_hostIP cString];
	if ((p = strchr(cs, ':')) && (strchr(++p, ':')))		// 2 or more ':'
		{
		u.sa6.sin6_family = AF_INET6;						// IPv6
		u.sa6.sin6_port = htons(_port);
		r = inet_pton(AF_INET6, cs, &u.sa6.sin6_addr);
		addrlen = sizeof(u.sa6);
		}
	else													// IPv4
		{
		u.sa.sin_family = AF_INET;
		u.sa.sin_port = htons(_port);
		r = inet_aton(cs, &u.sa.sin_addr);
		addrlen = sizeof(u.sa);
		}

	if (r != 1)
		{
		NSLog(@"Failed to convert URL IP address");
		return nil;
		}

	return [NSData dataWithBytes:&u length:addrlen];
}

- (id) initWithCoder:(NSCoder*)decoder		{ return self; }
- (void) encodeWithCoder:(NSCoder*)coder	{}

@end  /* NSURL */

/* ****************************************************************************

	NSURLRequest, NSMutableURLRequest

** ***************************************************************************/

@implementation NSURLRequest

+ (id) requestWithURL:(NSURL *)url
{
	return [[[self alloc] initWithURL:url] autorelease];
}

+ (id) requestWithURL:(NSURL *)url
		  cachePolicy:(NSURLRequestCachePolicy)policy
		  timeoutInterval:(NSTimeInterval)timeout
{
	return [[[self alloc] initWithURL:url
						  cachePolicy:policy
						  timeoutInterval:timeout] autorelease];
}

- (id) initWithURL:(NSURL *)url
{
	return [self initWithURL:url
				 cachePolicy:NSURLRequestUseProtocolCachePolicy
				 timeoutInterval:-1.0];
}

- (id) initWithURL:(NSURL *)url
	   cachePolicy:(NSURLRequestCachePolicy)policy
	   timeoutInterval:(NSTimeInterval)timeout
{
	if ((self = [super init]))
		{
		_url = [url retain];
		_rq.policy = policy;
		_timeout = timeout;
		_method = @"GET";
		_rq.cookies = NSURLRequestReloadIgnoringCacheData;
		}

	return self;
}

- (void) dealloc
{
	[_url release],				_url = nil;
	[_method release],			_method = nil;
	[_headerFields release],	_headerFields = nil;

	[super dealloc];
}

- (NSString *) _header
{
	NSString *fmt = @"%@ %@ HTTP/1.0\r\n%@Host: %@\r\n%@\r\n\r\n";
//	NSString *c = @"Connection: Keep-Alive";
	NSString *c = @"User-agent: mGSTEP\r\nConnection: close";
	NSString *path = [_url path];
	NSString *host = [_url host];
	NSString *user = [_url user];
	NSString *pass = [_url password];
	NSString *auth;

	if (_headerFields)
		c = [_headerFields objectForKey:@"Connection"];

	if (user && pass)
		{
		NSString *raw = [NSString stringWithFormat:@"%@:%@", user, pass];
		NSString *b64;

		b64 = [[raw dataUsingEncoding:NSUTF8StringEncoding] base64String];
		auth = [NSString stringWithFormat: @"Authorization: Basic %@", b64];
		}

#if 0
	if (_query)
		{
		NSString *t = @"Content-Type: application/x-www-form-urlencoded\n";
		NSString *f = @"%@%@Content-Length: %d\n\n%@\n";
		int l = [_query length];

		_header = [NSString stringWithFormat:f, _header, t, l, _query];
		}
#endif

	return [NSString stringWithFormat: fmt, _method, path, __content, host, c];
}

- (NSURL *) URL								{ return _url; }
- (NSString *) HTTPMethod					{ return _method; }
- (NSDictionary *) allHTTPHeaderFields		{ return _headerFields; }
- (NSURLRequestCachePolicy) cachePolicy		{ return _rq.policy; }
- (BOOL) HTTPShouldHandleCookies			{ return _rq.cookies; }
- (NSTimeInterval) interval					{ return _timeout; }

- (NSString *) valueForHTTPHeaderField:(NSString *)field
{
	return [_headerFields objectForKey:[field lowercaseString]];
}

- (id) copy									{ return [self retain]; }

- (id) mutableCopy
{
	NSURLRequest *rq = [NSMutableURLRequest alloc];

	if (rq)
		{
		rq->_url = [_url copy];
		rq->_rq.policy = _rq.policy;
		rq->_timeout = _timeout;
		rq->_method = [_method copy];
		rq->_headerFields = [_headerFields mutableCopy];
		rq->_rq.cookies = _rq.cookies;
		}
		
	return rq;
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"%@ URL=%@ Policy=%d time=%f METH=%@ %@",
						NSStringFromClass(isa), _url, _rq.policy,
						_timeout, _method, _headerFields];
}

- (id) initWithCoder:(NSCoder*)aDecoder			{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder		{}

@end  /* NSURLRequest */


@implementation NSMutableURLRequest

- (void) setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
	if (!_headerFields)
		_headerFields = [[NSMutableDictionary alloc] initWithCapacity:10];
	[_headerFields setObject:value forKey:[field lowercaseString]];
}

- (void) addValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
	NSString *c = [_headerFields objectForKey:[field lowercaseString]];
						// append string (comma separated) if already defined
	c = (c) ? [c stringByAppendingFormat:@",%@", value] : value;
	[self setValue:c forHTTPHeaderField:field];			// add to header fields
}

- (void) setAllHTTPHeaderFields:(NSDictionary *)headers
{
	[_headerFields autorelease];
	_headerFields = [headers mutableCopy];
	// FIXME: copy to lower case dictionary keys!
}

- (void) setCachePolicy:(NSURLRequestCachePolicy)policy	{ _rq.policy = policy; }
- (void) setHTTPMethod:(NSString *)m					{ ASSIGN(_method, m); }
- (void) setHTTPShouldHandleCookies:(BOOL)flag			{ _rq.cookies = flag; }
- (void) setTimeoutInterval:(NSTimeInterval)to			{ _timeout = to; }
- (void) setURL:(NSURL *)url							{ ASSIGN(_url, url); }
- (void) setHTTPBody:(NSData *)data						{ NIMP; }

- (id) copy
{
	NSMutableURLRequest *rq = [NSURLRequest alloc];

	if (rq)
		{
		rq->_url = [_url retain];
		rq->_rq.policy = _rq.policy;
		rq->_timeout = _timeout;
		rq->_method = [_method retain];
		rq->_headerFields = [_headerFields copy];
		rq->_rq.cookies = _rq.cookies;
		}
		
	return rq;
}

- (id) initWithCoder:(NSCoder*)decoder		{ return self; }
- (void) encodeWithCoder:(NSCoder*)coder	{}

@end  /* NSMutableURLRequest */

/* ****************************************************************************

	NSURLResponse

** ***************************************************************************/

@implementation NSURLResponse

+ (id) alloc
{
	return NSAllocateObject([NSHTTPURLResponse class]);
}

- (id) initWithURL:(NSURL *)url
		  MIMEType:(NSString *)type
		  expectedContentLength:(NSInteger)length
		  textEncodingName:(NSString *)name
{
	_url = [url retain];
//	_mimeType = [_mimeExtensions objectForKey:[[URL path] pathExtension]];
	_mimeType = (!type) ? @"text/html" : [type retain];   // FIX ME from ext ???
	_textEncodingName = [name retain];
	_expectedContentLength = (length < 0) ? 0 : length;
	
	return self;
}

- (void) dealloc
{
	[_url release],					_url = nil;
	[_mimeType release],			_mimeType = nil;
	[_textEncodingName release],	_textEncodingName = nil;

	[super dealloc];
}

- (NSURL *) URL								{ return _url; }
- (NSString *) MIMEType						{ return _mimeType; }
- (NSString *) textEncodingName				{ return _textEncodingName; }
- (NSString *) suggestedFilename			{ return nil; }
- (long long) expectedContentLength			{ return _expectedContentLength; }

- (id) copy									{ return self; }

- (id) initWithCoder:(NSCoder*)decoder		{ return self; }
- (void) encodeWithCoder:(NSCoder*)coder	{}

@end  /* NSURLResponse */


@implementation NSHTTPURLResponse

- (id) initWithURL:(NSURL*)url
		statusCode:(NSInteger)code
		HTTPVersion:(NSString*)version
		headerFields:(NSDictionary*)fields
{
	_url = [url retain];
//	_version = (version) ? [version retain] : @"1.1";
	_mimeType = @"text/html";
	_headerFields = [fields retain];
	_statusCode = code;
	
	return self;
}

- (void) dealloc
{
	[_headerFields release],	_headerFields = nil;
	[super dealloc];
}

- (NSString *) textEncodingName
{
	return [_headerFields objectForKey: @"Content-Encoding"];
}

- (NSInteger) statusCode					{ return _statusCode; }
- (NSDictionary *) allHeaderFields			{ return _headerFields; }

@end  /* NSHTTPURLResponse */

/* ****************************************************************************

	NSCachedURLResponse

** ***************************************************************************/

@implementation NSCachedURLResponse

- (id) initWithResponse:(NSURLResponse *)response data:(NSData *)data
{
	return nil;
}

- (id) initWithResponse:(NSURLResponse *)response
				   data:(NSData *)data
				   userInfo:(NSDictionary *)userInfo
				   storagePolicy:(NSURLCacheStoragePolicy)policy
{
	return nil;
}

- (NSData *) data								{ return nil; }
- (NSURLResponse *) response					{ return nil; }
- (NSURLCacheStoragePolicy) storagePolicy		{ return 0; }
- (NSDictionary *) userInfo						{ return nil; }

- (id) copy										{ return [self retain]; }
- (id) initWithCoder:(NSCoder*)aDecoder			{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder		{}

@end  /* NSCachedURLResponse */

/* ****************************************************************************

	NSURLCredential

** ***************************************************************************/

@implementation NSURLCredential

+ (NSURLCredential *) credentialForTrust:(SecTrustRef)trust
{
	return [[[self alloc] initWithTrust: trust] autorelease];
}

- (id) initWithTrust:(SecTrustRef)trust
{
	_trust = CFRetain(trust);

	return self;
}

- (void) dealloc
{
    CFRelease(_trust);

	[super dealloc];
}

- (NSURLCredentialPersistence) persistence		{ return _persistence; }

- (id) copy										{ return [self retain]; }
- (id) initWithCoder:(NSCoder*)aDecoder			{ return self; }
- (void) encodeWithCoder:(NSCoder*)aCoder		{}

@end

/* ****************************************************************************

	NSURLAuthenticationChallenge

** ***************************************************************************/

@implementation NSURLAuthenticationChallenge

- (id) initWithProtectionSpace:(NSURLProtectionSpace *)ps
			proposedCredential:(NSURLCredential *)credential
			previousFailureCount:(NSInteger)fails
			failureResponse:(NSURLResponse *)response
			error:(NSError *)error
			sender:(id <NSURLAuthenticationChallengeSender>)sender
{
	_protectionSpace    = [ps retain];
	_proposedCredential = [credential retain];
	_failureResponse    = [response retain];
	_sender = [sender retain];
	_error  = [error retain];

	_previousFailCount = fails;

	return self;
}

- (id) initWithAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch
			sender:(id <NSURLAuthenticationChallengeSender>)sender
{
	_protectionSpace    = [ch->_protectionSpace retain];
	_proposedCredential = [ch->_proposedCredential retain];
	_failureResponse    = [ch->_failureResponse retain];
	_error  = [ch->_error retain];
	_sender = [sender retain];

	return self;
}

- (void) dealloc
{
	[_protectionSpace release];
	[_proposedCredential release];
	[_failureResponse release];
	[_sender release];
	[_error release];

	[super dealloc];
}

- (id <NSURLAuthenticationChallengeSender>) sender		 { return _sender; }
- (NSURLProtectionSpace *) protectionSpace		{ return _protectionSpace; }
- (NSURLCredential *) proposedCredential		{ return _proposedCredential; }
- (NSURLResponse *) failureResponse				{ return _failureResponse; }
- (NSInteger) previousFailureCount				{ return _previousFailCount; }
- (NSError *) error								{ return _error; }

@end  /* NSURLAuthenticationChallenge */

/* ****************************************************************************

	NSURLProtocol

** ***************************************************************************/

@interface NSURLProtocol  (responder)
- (BOOL) _respondWithHTTP:(NSMutableData *)mdata;
@end

@interface _NSURLProtocolHTTP : NSURLProtocol
@end

@interface NSMutableData  (_NSDataDecompressGZ)
- (id) decompressGZ;
@end


@implementation _NSURLProtocolHTTP

+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
	return [[[request URL] scheme] isEqualToString: @"http"];
}

@end


static Class
_LoadPlugin(NSString *plugin)
{
	Class c = Nil;
	NSString *p = [[NSBundle systemBundle] pathForResource:plugin
										   ofType:@"bundle"
										   inDirectory:@"Foundation/Plugins"];
	if (p)
		{
		NSBundle *bundle = [[NSBundle alloc] initWithPath:p];

		if (bundle)
			{
			NSLog(@"Loading bundle %@", p);
			if (!(c = [bundle principalClass]))
				NSLog(@"Error loading principalClass of bundle %@", p);
			}
		else
			NSLog(@"Error loading bundle %@", p);
		}

	return c;
}

@implementation NSURLProtocol

+ (id) alloc											{ return nil; }
+ (BOOL) canInitWithRequest:(NSURLRequest *)request		{ return NO; }

+ (BOOL) registerClass:(Class)protocolClass
{
	if (!__registeredURLProtocols)
		{
		__registeredURLProtocols = [NSMutableArray new];
		[__registeredURLProtocols addObject: [_NSURLProtocolHTTP class]];
		}
	[__registeredURLProtocols addObject: protocolClass];

	return YES;
}

+ (void) unregisterClass:(Class)protocolClass
{
	[__registeredURLProtocols removeObject: protocolClass];
}

- (id) initWithRequest:(NSURLRequest *)request
		cachedResponse:(NSCachedURLResponse *)cachedResponse
		client:(id <NSURLProtocolClient>)client
{
	_request = [request copy];
	_cachedResponse = [cachedResponse retain];
	_client = client;
	_header = [[_request _header] retain];

	return self;
}

- (void) dealloc
{
	if (isa != [NSURLProtocol class])
		{
		[self stopLoading];
		[_request release],			_request = nil;
		[_cachedResponse release],	_cachedResponse = nil;
		[_data release],			_data = nil;
		}

	[super dealloc];
}

- (NSURLRequest *) request							{ return _request; }
- (id <NSURLProtocolClient>) client					{ return _client; }
- (NSCachedURLResponse *) cachedResponse			{ return _cachedResponse; }

- (void) startLoading
{
	[(NSURLConnection *)_client scheduleInRunLoop:[NSRunLoop currentRunLoop]
								forMode:NSDefaultRunLoopMode];
}

- (void) stopLoading
{
	[(NSURLConnection *)_client unscheduleFromRunLoop:[NSRunLoop currentRunLoop]
								forMode:NSDefaultRunLoopMode];
}

- (BOOL) _respondWithHTTP:(NSMutableData *)mdata
{
	NSString *k[] = { @"Content-Type",   @"Content-Encoding",
					  @"Content-Length", @"Connection", @"Transfer-Encoding" };
	NSString *v[] = { @"", @"", @"", @"close" };
	NSDictionary *hd;
	NSURLResponse *rp;
	NSUInteger l = [mdata length];
	const char *by = [mdata bytes];
	const char *e, *p, *ep;
	char codeBuf[16] = {0};
	NSInteger code;

	if (l < strlen("HTTP/1.0 200 OK") || *by != 'H' || *(by+1) != 'T')
		return NO;								// malformed response

	for (p = by; *p != ' ' && p < (by+12); p++);
	if (*p != ' ')
		return NO;								// malformed response

	memcpy(codeBuf, ++p, 3);
	code = (NSInteger)atol(codeBuf);

	[mdata appendBytes:"\0" length:1];
	if (!(e = strstr(by, "\r\n\r\n")) && !(e = strstr(by, "\n\n")))
		{
		[mdata setLength: l];
		return NO;								// incomplete response
		}

//	NSLog(@"HTTP Response Raw Header: '%s'\n", by);
	if ((p = strstr(by, "Content-Type:")))
		{
		p += sizeof("Content-Type:");
		if ((ep = strstr(p, "\r\n")))
			v[0] = [NSString stringWithCString:p length: (ep - p)];
		}
	if ((p = strstr(by, "Content-Encoding:")))
		{
		p += sizeof("Content-Encoding:");
		if ((ep = strstr(p, "\r\n")))
			v[1] = [NSString stringWithCString:p length: (ep - p)];
		_up.gzip = ([v[1] isEqualToString: @"gzip"]);
		}
	if ((p = strstr(by, "Content-Length:")))
		{
		p += sizeof("Content-Length:");
		if ((ep = strstr(p, "\r\n")))
			v[2] = [NSString stringWithCString:p length: (ep - p)];
		memset(codeBuf, 0, sizeof(codeBuf));
		memcpy(codeBuf, p, (ep - p));
		_length = (NSInteger)atol(codeBuf);
		}
	if ((p = strstr(by, "Connection:")))
		{
		p += sizeof("Connection:");
		if (strncmp(p, "close", strlen("close")) && (ep = strstr(p, "\r\n")))
			v[3] = [NSString stringWithCString:p length: (ep - p)];
		}
//	_up.chunked = YES;	// FIX ME RFC7230 HTTP/1.1  Transfer-Encoding: chunked
	hd = [NSDictionary dictionaryWithObjects:v forKeys:k count:4];

	e += (*e == '\r') ? 4 : 2;
	memmove((void *)by, (void *)e, (l - (e - by)));
	[mdata setLength: (l - (e - by))];

	rp = [[NSHTTPURLResponse alloc] initWithURL: [_request URL]
									statusCode:  code
									HTTPVersion: nil
									headerFields:hd];
	_up.responded = YES;
	[_client URLProtocol:self
			 didReceiveResponse:rp
			 cacheStoragePolicy:NSURLRequestUseProtocolCachePolicy];
	[rp release];
	
	return YES;
}

- (void) _receivedEvent:(void*)data						// called by Connection
				   type:(CFSocketCallBackType)type		// when select() says
				   extra:(const void*)extra				// the fd is ready
{
	char buf[3584] = {0};
	int read_data = 0;
	int size;

	DBLog(@"NSURLProtocol _receivedEvent");
	if (!_up.queried)
		{
		_up.queried = YES;
///		printf ("query string:\n'%s'\n", [_header cString]);

		if (write(PTR2INT(extra), [_header cString], [_header length]) == -1)
			NSLog(@"URL: error writing to socket\n");
		return;
		}

	if (!_data)
		_data = [NSMutableData new];
															// read response
	for (;(size = read (PTR2INT(extra), buf, 3584)) > 0; read_data++)
		[_data appendBytes:buf length:size];

	if (read_data)
		{
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

	if (size < 0 && errno != EAGAIN && errno != 0)
		{
		NSLog(@"URL: Error in read() %d - %s\n", errno, strerror(errno));
		[_client URLProtocol:self didFailWithError:nil];
		}
	else
		{
		DBLog(@"URL: NSURLProtocol read %d %d\n", size, read_data);
		if (size == 0 && read_data == 0)
			{
			NSLog(@"URL: NSURLProtocol complete\n");
			[_client URLProtocolDidFinishLoading: self];
			}
		}
}

@end  /* NSURLProtocol */

/* ****************************************************************************

	NSURLConnection

** ***************************************************************************/

static void
_ConnectionCallback( CFSocketRef socket,				// called by NSRunLoop
					 CFSocketCallBackType type,			// when select() says
					 CFDataRef address,					// the fd is connected
					 const void *data,
					 void *clientCallBackInfo)
{
	NSURLConnection *cn = (NSURLConnection *)clientCallBackInfo;
	_NSURLConnection *p = (_NSURLConnection *)cn;
	CFSocketNativeHandle sd = CFSocketGetNative(socket);

	if (!p->_uc.connected)
		{
		int se = PTR2INT(data);							// socket errno

		if (se != 0)
			{
			NSError *e = _NSError(NSPOSIXErrorDomain, se, @"connect error");

			NSLog(@"Error during connect (%d) %s\n", se, strerror(se));
			[(id <NSURLProtocolClient>)cn URLProtocol:p->_protocol
										  didFailWithError:e];
			return;
			}

		NSLog(@"Connected %d - %s\n", se, strerror(se));
		p->_uc.connected = YES;
		}

	[p->_protocol _receivedEvent:p->_delegate type:type extra:INT2PTR(sd)];
// *data Data appropriate for the callback type. For a kCFSocketConnectCallBack
// that failed in the background, it is a pointer to an SInt32 error code
}

static id
_AllocURLProtocol(NSURLRequest *r)
{
	NSString *scheme;
	Class c;

	if (__registeredURLProtocols)
		{
		NSInteger count = [__registeredURLProtocols count];
		Class urlProto;
		
		while (count-- > 0)
			{
			urlProto = [__registeredURLProtocols objectAtIndex: count];
			if ([urlProto canInitWithRequest: r])
				return NSAllocateObject(urlProto);
		}	}

	if (!__gzPlugin && (__gzPlugin = _LoadPlugin(@"GZ")))
		__content = @"Accept: */*\r\nAccept-Encoding: gzip\r\n";
	if ([(scheme = [[r URL] scheme]) isEqualToString: @"http"])
		return NSAllocateObject([_NSURLProtocolHTTP class]);
	if ([scheme isEqualToString: @"https"])
		if ((c = _LoadPlugin(@"HTTPS")))
			{
			[NSURLProtocol registerClass: c];

			return NSAllocateObject(c);
			}

	return nil;
}


@implementation NSURLConnection

+ (BOOL) canHandleRequest:(NSURLRequest *)request		{ return YES; }

+ (NSURLConnection *) connectionWithRequest:(NSURLRequest *)request
								   delegate:(id)delegate
{
	return [[[self alloc] initWithRequest:request
						  delegate:delegate
						  startImmediately:YES] autorelease];
}

- (id) initWithRequest:(NSURLRequest *)r delegate:(id)delegate
{
	return [self initWithRequest:r delegate:delegate startImmediately:YES];
}

- (id) initWithRequest:(NSURLRequest *)request
			  delegate:(id)delegate
			  startImmediately:(BOOL)flag
{
	if ((self = [super init]))
		{
		if (!(_protocol = _AllocURLProtocol(request)))
			return _NSInitError(self, @"no URL protocol for %@", request);

		_protocol = [_protocol initWithRequest:request
							   cachedResponse:nil
							   client:(id <NSURLProtocolClient>)self];
		_delegate = delegate;
		_request = [request retain];

		if (flag)
			[self start];
		}

	return self;
}

- (void) dealloc
{
	[_request release],		_request = nil;
	[_protocol release],	_protocol = nil;
	if (_socket)
		[self unscheduleFromRunLoop:nil forMode:nil];
	[super dealloc];
}

- (NSURLRequest *) originalRequest			{ return _request; }
- (NSURLRequest *) currentRequest			{ return _request; } // FIX ME redirects

- (void) cancel								{ [_protocol stopLoading]; }
- (void) start								{ [_protocol startLoading]; }

- (void) scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode
{
	CFOptionFlags fl = kCFSocketConnectCallBack | kCFSocketReadCallBack;
	CFSocketContext cx = { 1, self, NULL, NULL, NULL };
	NSData *address;

	if (!(address = [[_request URL] _socketAddress]))
		return;

	_socket = CFSocketCreate (NULL, 0, 0, 0, fl, &_ConnectionCallback, &cx);

	if (CFSocketConnectToAddress(_socket, (CFDataRef)address, -1) < 0)
		NSLog(@"CFSocketConnectToAddress failed to connect");
	else
		{
		CFRunLoopSourceRef rs;

		if ((rs = CFSocketCreateRunLoopSource(NULL, _socket, 0)) == NULL)
			[NSException raise:NSGenericException format:@"CFSocket init error"];
		CFRunLoopAddSource((CFRunLoopRef)rl, rs, (CFStringRef)mode);
		CFRelease(rs);
		}
}

- (void) unscheduleFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode
{
	if (!_socket)
		return;

	if (mode && rl)
		{
		CFRunLoopSourceRef rs = ((CFSocket *)_socket)->runLoopSource;

		CFRunLoopRemoveSource((CFRunLoopRef)rl, rs, (CFStringRef)mode);
		}
	else
		{
		CFSocketRef s = _socket;
		
		_socket = NULL;
		CFSocketInvalidate(s);
		CFRelease(s);
		}
}

- (void) URLProtocol:(NSURLProtocol *)proto
		 wasRedirectedToRequest:(NSURLRequest *)request
		 redirectResponse:(NSURLResponse *)redirectResponse
{
	NSURLRequest *r = [_delegate connection:self
								 willSendRequest:request
								 redirectResponse:redirectResponse];
	if (!r)
		[proto stopLoading];
	NSLog(@"wasRedirectedToRequest:%@", request);	// FIX ME send new request
}

- (void) URLProtocol:(NSURLProtocol *)proto didFailWithError:(NSError *)error
{
	if (!_uc.done)
		{
		_uc.done = YES;
		[_delegate connection:self didFailWithError:error];
		[self unscheduleFromRunLoop:nil forMode:nil];
		}
}

- (void) URLProtocol:(NSURLProtocol *)proto
		 didReceiveResponse:(NSURLResponse *)response
		 cacheStoragePolicy:(NSURLCacheStoragePolicy)policy
{
	[_delegate connection:self didReceiveResponse:response];
}

- (void) URLProtocolDidFinishLoading:(NSURLProtocol *)proto
{
	if (!_uc.done)
		{
		_uc.done = YES;
		[_delegate connectionDidFinishLoading:self];
		[self unscheduleFromRunLoop:nil forMode:nil];
		}
}

- (void) URLProtocol:(NSURLProtocol *)proto didLoadData:(NSData *)data
{
	[_delegate connection:self didReceiveData:data];
}

@end  /* NSURLConnection */
