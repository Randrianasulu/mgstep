/*
   NSURL.h

   URL loading classes

   Copyright (C) 2009-2016 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	October 2009

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSURL
#define _mGSTEP_H_NSURL

#include <Foundation/NSObject.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSRange.h>

@class NSData;
@class NSError;
@class NSNumber;
@class NSRunLoop;
@class NSDictionary;
@class NSMutableDictionary;
@class NSURLProtocol;
@class NSURLCredential;
@class NSURLProtectionSpace;
@class NSURLAuthenticationChallenge;
@class NSMutableData;

extern NSString *NSURLErrorDomain;
extern NSString *NSErrorFailingURLStringKey;


/* ****************************************************************************

	NSURL	(scheme : resourceSpecifier)   RFC1808, RFC1738 and RFC2732

	scheme				https
	resourceSpecifier   ...

	//john:p4ssw0rd@www.example.com:443/script.ext;param=value?query=value#ref
	
	user				john
	password			p4ssw0rd
	host				www.example.com
	port				443
	path				/script.ext
	pathExtension		ext
	pathComponents		["/", "script.ext"]
	parameterString		param=value
	query				query=value
	fragment			ref

** ***************************************************************************/

@interface NSURL : NSObject  <NSCoding, NSCopying>
{
	NSString *_urlString;

	NSURL *_baseURL;

	NSString *_scheme;
	NSString *_host;
	NSString *_hostIP;
	NSString *_user;
	NSString *_password;
	NSString *_path;

	int _port;

	NSRange _parameter;
	NSRange _query;
	NSRange _fragment;
	NSRange _resource;

	NSUInteger _hash;
}

+ (id) URLWithString:(NSString *)urlString;
+ (id) URLWithString:(NSString *)urlString relativeToURL:(NSURL *)baseURL;
+ (id) fileURLWithPath:(NSString *)path;
//+ (id) fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;

- (id) initWithString:(NSString *)urlString;
- (id) initWithString:(NSString *)urlString relativeToURL:(NSURL *)baseUrl;
- (id) initFileURLWithPath:(NSString *)path;
//- (id) initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;

- (NSString *) scheme;
- (NSString *) host;
- (NSString *) user;
- (NSString *) password;
- (NSString *) path;
- (NSNumber *) port;
- (NSString *) parameterString;
- (NSString *) query;
- (NSString *) fragment;
- (NSString *) absoluteString;
- (NSString *) relativeString;
- (NSString *) relativePath;			 // path portion of relative URL
- (NSString *) lastPathComponent;
- (NSString *) resourceSpecifier;

- (NSURL *) absoluteURL;
- (NSURL *) baseURL;

- (BOOL) isFileURL;
- (BOOL) getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)max;
- (const char *) fileSystemRepresentation;

@end  /* NSURL */


@interface NSURL (SocketAddressExtension)

- (NSData *) _socketAddress;

@end

/* ****************************************************************************

	NSURLRequest

** ***************************************************************************/

typedef enum {
    NSURLRequestUseProtocolCachePolicy = 0,	  // use protocol caching policy
	NSURLRequestReloadIgnoringLocalCacheData          = 1,
	NSURLRequestReturnCacheDataElseLoad               = 2,
	NSURLRequestReturnCacheDataDontLoad               = 3,
	NSURLRequestReloadIgnoringLocalAndRemoteCacheData = 4,
	NSURLRequestReloadRevalidatingCacheData           = 5,
	NSURLRequestReloadIgnoringCacheData = 1  // load from source, ignore cache
} NSURLRequestCachePolicy;


@interface NSURLRequest : NSObject  <NSCoding, NSCopying, NSMutableCopying>
{
	NSURL *_url;
	NSString *_method;
	NSTimeInterval _timeout;
	NSMutableDictionary	*_headerFields;

	struct __URLRequestFlags {
		NSURLRequestCachePolicy policy:3;
		unsigned int cookies:1;
		unsigned int reserved:4;
	} _rq;
}

+ (id) requestWithURL:(NSURL *)url;
+ (id) requestWithURL:(NSURL *)url
		  cachePolicy:(NSURLRequestCachePolicy)cachePolicy
		  timeoutInterval:(NSTimeInterval)timeoutInterval;

- (id) initWithURL:(NSURL *)url;
- (id) initWithURL:(NSURL *)url
	   cachePolicy:(NSURLRequestCachePolicy)policy
	   timeoutInterval:(NSTimeInterval)timeout;

- (NSURL *) URL;
- (NSString *) HTTPMethod;
- (NSDictionary *) allHTTPHeaderFields;
- (NSURLRequestCachePolicy) cachePolicy;
- (BOOL) HTTPShouldHandleCookies;
- (NSTimeInterval) interval;

@end  /* NSURLRequest */


@interface NSMutableURLRequest : NSURLRequest  <NSCoding, NSCopying>

//- (void) setMainDocumentURL:(NSURL *)url;
//- (void) setHTTPBodyStream:(NSInputStream *)stream;

- (void) setHTTPMethod:(NSString *)method;
- (void) setHTTPBody:(NSData *)data;

@end  /* NSMutableURLRequest */

/* ****************************************************************************

	NSURLResponse

** ***************************************************************************/

@interface NSURLResponse : NSObject  <NSCoding, NSCopying>
{
	NSURL *_url;
	NSString *_mimeType;
	NSString *_textEncodingName;
	long long _expectedContentLength;
}

- (id) initWithURL:(NSURL *)url
		  MIMEType:(NSString *)MIMEType
		  expectedContentLength:(NSInteger)length 
		  textEncodingName:(NSString *)name;

- (NSURL *) URL;
- (NSString *) MIMEType;
- (NSString *) suggestedFilename;
- (NSString *) textEncodingName;

- (long long) expectedContentLength;

@end  /* NSURLResponse */


@interface NSHTTPURLResponse : NSURLResponse
{
	int _statusCode;
	NSDictionary *_headerFields;
}

- (id) initWithURL:(NSURL*)url
		statusCode:(NSInteger)code
		HTTPVersion:(NSString*)version
		headerFields:(NSDictionary*)fields;

- (NSInteger) statusCode;
- (NSDictionary *) allHeaderFields;

@end  /* NSHTTPURLResponse */

/* ****************************************************************************

	NSURLCache / NSCachedURLResponse	(Not Implemented)

** ***************************************************************************/

typedef enum _NSURLCacheStoragePolicy {
	NSURLCacheStorageAllowed,
	NSURLCacheStorageAllowedInMemoryOnly,
	NSURLCacheStorageNotAllowed,
} NSURLCacheStoragePolicy;


@interface NSCachedURLResponse : NSObject  <NSCoding, NSCopying>
{
	NSData *_data;
	NSURLResponse *_response;
	NSDictionary *_userInfo;
	NSURLCacheStoragePolicy _storagePolicy;
}

- (id) initWithResponse:(NSURLResponse *)response data:(NSData *)data;
- (id) initWithResponse:(NSURLResponse *)response
				   data:(NSData *)data
				   userInfo:(NSDictionary *)userInfo
				   storagePolicy:(NSURLCacheStoragePolicy)policy;
- (NSData *) data;
- (NSURLResponse *) response;
- (NSURLCacheStoragePolicy) storagePolicy;
- (NSDictionary *) userInfo;

@end  /* NSCachedURLResponse */


@interface NSURLCache : NSObject
{
}

+ (NSURLCache *) sharedURLCache;

+ (void) setSharedURLCache:(NSURLCache *)cache;

- (NSCachedURLResponse *) cachedResponseForRequest:(NSURLRequest *)request;
- (void) storeCachedResponse:(NSCachedURLResponse *)cachedResponse
				  forRequest:(NSURLRequest *)request;
- (void) removeCachedResponseForRequest:(NSURLRequest *)request;
- (void) removeAllCachedResponses;
// ...

@end  /* NSURLCache */

/* ****************************************************************************

	NSURLAuthenticationChallenge

** ***************************************************************************/

@protocol NSURLAuthenticationChallengeSender  <NSObject>

- (void) useCredential:(NSURLCredential *)credential
		 forAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch;
- (void) continueWithoutCredentialForAuthenticationChallenge:\
		 (NSURLAuthenticationChallenge *)ch;

- (void) cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch;

- (void) performDefaultHandlingForAuthenticationChallenge:\
		 (NSURLAuthenticationChallenge *)ch;
- (void) rejectProtectionSpaceAndContinueWithChallenge:\
		 (NSURLAuthenticationChallenge *)ch;
@end


@interface NSURLAuthenticationChallenge : NSObject
{
	id <NSURLAuthenticationChallengeSender> _sender;
	NSURLProtectionSpace *_protectionSpace;
	NSURLCredential *_proposedCredential;
	NSURLResponse *_failureResponse;
	NSError *_error;

	NSInteger _previousFailCount;
}

- (id) initWithProtectionSpace:(NSURLProtectionSpace *)ps
			proposedCredential:(NSURLCredential *)credential
			previousFailureCount:(NSInteger)fails
			failureResponse:(NSURLResponse *)response
			error:(NSError *)error
			sender:(id <NSURLAuthenticationChallengeSender>)sender;

- (id) initWithAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch
			sender:(id <NSURLAuthenticationChallengeSender>)sender;

- (id <NSURLAuthenticationChallengeSender>) sender;		// reply obj when done

- (NSURLProtectionSpace *) protectionSpace;
- (NSURLCredential *) proposedCredential;
- (NSURLResponse *) failureResponse;
- (NSInteger) previousFailureCount;
- (NSError *) error;

@end  /* NSURLAuthenticationChallenge */

/* ****************************************************************************

	NSURLProtocol

** ***************************************************************************/

@protocol NSURLProtocolClient  <NSObject>

- (void) URLProtocolDidFinishLoading:(NSURLProtocol *)proto;
- (void) URLProtocol:(NSURLProtocol *)proto
		 cachedResponseIsValid:(NSCachedURLResponse *)resp;
- (void) URLProtocol:(NSURLProtocol *)proto
		 didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch;
- (void) URLProtocol:(NSURLProtocol *)proto didFailWithError:(NSError *)error;
- (void) URLProtocol:(NSURLProtocol *)proto didLoadData:(NSData *)data;
- (void) URLProtocol:(NSURLProtocol *)proto
		 didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)ch;
- (void) URLProtocol:(NSURLProtocol *)proto 
		 didReceiveResponse:(NSURLResponse *)response 
		 cacheStoragePolicy:(NSURLCacheStoragePolicy)policy;
- (void) URLProtocol:(NSURLProtocol *)proto
		 wasRedirectedToRequest:(NSURLRequest *)request 
		 redirectResponse:(NSURLResponse *)redirectResponse;
@end


@interface NSURLProtocol : NSObject
{
	NSCachedURLResponse *_cachedResponse;
	NSURLRequest *_request;
	NSString *_header;

	id _client;

	NSMutableData *_data;
	NSInteger _length;

	struct __URLProtocolFlags {
		unsigned int authenticated:1;
		unsigned int queried:1;
		unsigned int responded:1;
		unsigned int chunked:1;
		unsigned int decompressed:1;
		unsigned int gzip:1;
		unsigned int reserved:2;
	} _up;
}

+ (BOOL) canInitWithRequest:(NSURLRequest *)request;

+ (BOOL) registerClass:(Class)protocolClass;
+ (void) unregisterClass:(Class)protocolClass;

- (id) initWithRequest:(NSURLRequest *)request
		cachedResponse:(NSCachedURLResponse *)cachedResponse
		client:(id <NSURLProtocolClient>)client;

- (id <NSURLProtocolClient>) client;
- (NSURLRequest *) request;
- (NSCachedURLResponse *) cachedResponse;

#if 0
+ (BOOL) requestIsCacheEquivalent:(NSURLRequest*)a toRequest:(NSURLRequest*)b;
+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request;
+ (id) propertyForKey:(NSString *)key inRequest:(NSURLRequest *)request;
+ (void) setProperty:(id)value
			  forKey:(NSString *)key
			  inRequest:(NSMutableURLRequest *)request;
#endif

- (void) startLoading;
- (void) stopLoading;

@end  /* NSURLProtocol */

/* ****************************************************************************

	NSURLConnection

** ***************************************************************************/

@protocol NSURLConnectionDelegate;

@interface NSURLConnection : NSObject
{
	NSURLRequest *_request;
	NSURLProtocol *_protocol;
	void *_socket;
	id _delegate;

	struct __URLConnectionFlags {
		unsigned int connected:1;
		unsigned int done:1;
		unsigned int reserved:6;
	} _uc;
}

+ (BOOL) canHandleRequest:(NSURLRequest *)request;

+ (NSURLConnection *) connectionWithRequest:(NSURLRequest *)request
								   delegate:(id)delegate;

- (id) initWithRequest:(NSURLRequest *)request delegate:(id)delegate;
- (id) initWithRequest:(NSURLRequest *)request
			  delegate:(id)delegate
			  startImmediately:(BOOL)flag;

- (void) start;
- (void) cancel;

- (void) scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void) unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

- (NSURLRequest *) originalRequest;
- (NSURLRequest *) currentRequest;		// req with any redirects or proto chgs

@end  /* NSURLConnection */


@protocol NSURLConnectionDelegate  <NSObject>

- (BOOL) connectionShouldUseCredentialStorage:(NSURLConnection *)connection;
- (void) connection:(NSURLConnection *)connect didFailWithError:(NSError *)e;
- (void) connection:(NSURLConnection *)connection
	willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)c;

- (void) connection:(NSURLConnection *)connection		// OSX deprecated
		 didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)c;
- (void) connection:(NSURLConnection *)connection
		 didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)c;
- (BOOL) connection:(NSURLConnection *)connection
		 canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)ps;

@end  /* NSURLConnectionDelegate  <NSObject> */


@protocol NSURLConnectionDataDelegate  <NSURLConnectionDelegate>

- (NSCachedURLResponse *) connection:(NSURLConnection *)connection
				   willCacheResponse:(NSCachedURLResponse *)cachedResponse;
- (NSURLRequest *) connection:(NSURLConnection *)connection
			  willSendRequest:(NSURLRequest *)request
			  redirectResponse:(NSURLResponse *)response;

- (void) connection:(NSURLConnection *)c didReceiveResponse:(NSURLResponse *)r;
- (void) connection:(NSURLConnection *)c didReceiveData:(NSData *)d;
- (void) connectionDidFinishLoading:(NSURLConnection *)c;

@end  /* NSURLConnectionDataDelegate  <NSURLConnectionDelegate> */


@interface NSURLConnection (NSURLConnectionSynchronousLoading)

+ (NSData *) sendSynchronousRequest:(NSURLRequest *)request
				  returningResponse:(NSURLResponse **)response
				  error:(NSError **)error;

@end  /* NSURLConnection (NSURLConnectionSynchronousLoading) */

/* ****************************************************************************

	NSURLDownload	(Not Implemented)

** ***************************************************************************/

@interface NSURLDownload : NSObject
{
}

- (id) initWithRequest:(NSURLRequest *)request delegate:(id)delegate;

- (NSURLRequest *) request;

- (void) cancel;

- (void) setDeletesFileUponFailure:(BOOL)flag;
- (BOOL) deletesFileUponFailure;

@end  /* NSURLDownload */


@interface NSObject (NSURLDownloadDelegate)

- (void) downloadDidBegin:(NSURLDownload *)download;
- (void) downloadDidFinish:(NSURLDownload *)download;
- (void) download:(NSURLDownload *)dnld didCreateDestination:(NSString *)path;
- (void) download:(NSURLDownload *)download didFailWithError:(NSError *)error;
- (void) download:(NSURLDownload *)download didReceiveDataOfLength:(unsigned)l;

@end

#endif  /* _mGSTEP_H_NSURL */
