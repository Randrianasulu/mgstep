/*
   NSStream.h

   Opaque data source or destination

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date: 	May 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_NSStream
#define _mGSTEP_H_NSStream

#include <Foundation/NSObject.h>

@protocol NSStreamDelegate;

@class NSError;
@class NSRunLoop;
@class NSString;
@class NSHost;


typedef enum {
    NSStreamStatusNotOpen = 0,
    NSStreamStatusOpening = 1,
    NSStreamStatusOpen    = 2,
    NSStreamStatusReading = 3,
    NSStreamStatusWriting = 4,
    NSStreamStatusAtEnd   = 5,
    NSStreamStatusClosed  = 6,
    NSStreamStatusError   = 7
} NSStreamStatus;

typedef enum {
    NSStreamEventNone              = 0,
    NSStreamEventOpenCompleted     = (1UL << 0),
    NSStreamEventHasBytesAvailable = (1UL << 1),
    NSStreamEventHasSpaceAvailable = (1UL << 2),
    NSStreamEventErrorOccurred     = (1UL << 3),
    NSStreamEventEndEncountered    = (1UL << 4)
} NSStreamEvent;

typedef unsigned char   uint8_t;

/* ****************************************************************************

	NSStream

	Abstract class, incapable of instantiation and intended to be subclassed.

	open the stream for reading or writing to make the stream available to
	the client directly or if scheduled on a run loop to the delegate.

	close the stream to remove the stream object from the run loop.
	closed stream should still be able to accept new properties and report
	its current properties. Once closed a stream cannot be reopened.

	delegate, a stream object is by default its own delegate. Setting nil must
	restore this. Do not retain the delegate to prevent retain cycles.

	scheduleInRunLoop:forMode: to schedule the stream object on the specified 
	run loop in the specified mode.
	
	removeFromRunLoop:forMode: to remove the object from the run loop. 
	Once the stream object for an open stream is scheduled on a run loop
	it is the responsibility of the subclass as it processes stream data to
	send: "stream:handleEvent:" messages to its delegate.

	Property API methods return and set property value of the specified key.
	Supports custom properties but s/handle all properties defined by NSStream.

	streamStatus returns the current status of the stream.
	
	streamError returns an NSError object representing the current error. 

** ***************************************************************************/

@interface NSStream : NSObject
{
	int _fd;									// CFSocketNativeHandle in CF
	void *_socket;								// CFSocketRef
	id <NSStreamDelegate> _delegate;
	NSStreamStatus _streamStatus;
	NSError *_streamError;

	struct __StreamFlags {
		unsigned int sendEvents:1;
		unsigned int closesNativeSocket:1;
		unsigned int reserved:30;
	} _sm;
}

- (void) open;
- (void) close;

- (void) scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode;
- (void) removeFromRunLoop:(NSRunLoop *)rl forMode:(NSString *)mode;

- (id <NSStreamDelegate>) delegate;
- (void) setDelegate:(id <NSStreamDelegate>)delegate;

- (id) propertyForKey:(NSString *)key;
- (BOOL) setProperty:(id)value forKey:(NSString *)key;		// Property API

- (NSStreamStatus) streamStatus;
- (NSError *) streamError;

@end

/* ****************************************************************************

	NSInputStream
	
	Abstract class representing the base functionality of a read stream.

** ***************************************************************************/

@interface NSInputStream : NSStream

    // read bytes into client-supplied buffer with max len size.
	// Returns the actual number of bytes read.
- (NSInteger) read:(uint8_t *)buffer maxLength:(NSUInteger)len;

    // returns pointer to a subclass-allocated buffer and the number of bytes
	// it contains. Buffer ptr is only valid until the next stream operation.
	// Subclass may return NO if this is not appropriate for the stream type.
	// Also may return NO if the buffer is not available.
- (BOOL) getBuffer:(uint8_t **)buffer length:(NSUInteger *)len;

    // returns YES if the stream has bytes available or requires a read to know
- (BOOL) hasBytesAvailable;

@end

/* ****************************************************************************

	NSOutputStream
	
	Abstract class representing the base functionality of a write stream.

** ***************************************************************************/

@interface NSOutputStream : NSStream

    // writes up to max len bytes from the buffer to the stream.
	// Returns the number of bytes actually written.
- (NSInteger) write:(const uint8_t *)buffer maxLength:(NSUInteger)len;

    // returns YES if stream can be written to or requires actual write to know
- (BOOL) hasSpaceAvailable;

@end


@protocol NSStreamDelegate <NSObject>				// optional

- (void) stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode;

@end


#if 0  /* NOT IMPLEMENTED ************************************************** */

									// convenience routines for NSInputStreams
@interface NSInputStream (NSInputStreamExtensions)

+ (id) inputStreamWithData:(NSData *)data;
+ (id) inputStreamWithFileAtPath:(NSString *)path;
+ (id) inputStreamWithURL:(NSURL *)url;

- (id) initWithData:(NSData *)data;
- (id) initWithFileAtPath:(NSString *)path;
- (id) initWithURL:(NSURL *)url;

@end

								// convenience routines for NSOutputStreams
@interface NSOutputStream (NSOutputStreamExtensions)

+ (id) outputStreamToMemory;
+ (id) outputStreamToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity;
+ (id) outputStreamToFileAtPath:(NSString *)path append:(BOOL)shouldAppend;
+ (id) outputStreamWithURL:(NSURL *)url append:(BOOL)shouldAppend;

- (id) initToMemory;
- (id) initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity;
- (id) initToFileAtPath:(NSString *)path append:(BOOL)shouldAppend;
- (id) initWithURL:(NSURL *)url append:(BOOL)shouldAppend;

@end

/* ****************************************************************************

	NSString constants for the "propertyForKey" / "setProperty:forKey:" API

	String constants for the setting of the socket security level.

** ***************************************************************************/

extern NSString * const NSStreamSocketSecurityLevelKey;		// key for setting
															// security level
extern NSString * const NSStreamSocketSecurityLevelNone;
extern NSString * const NSStreamSocketSecurityLevelSSLv2;
extern NSString * const NSStreamSocketSecurityLevelSSLv3;
extern NSString * const NSStreamSocketSecurityLevelTLSv1;
extern NSString * const NSStreamSocketSecurityLevelNegotiatedSSL;

	// NSDictionary containing the SOCKS proxy key/value pairs below
extern NSString * const NSStreamSOCKSProxyConfigurationKey;

extern NSString * const NSStreamSOCKSProxyHostKey;		// Value is an NSString
extern NSString * const NSStreamSOCKSProxyPortKey;		// Value is an NSNumber
extern NSString * const NSStreamSOCKSProxyUserKey;		// Value is an NSString
extern NSString * const NSStreamSOCKSProxyPasswordKey;	// Value is an NSString

extern NSString * const NSStreamSOCKSProxyVersionKey;
extern NSString * const NSStreamSOCKSProxyVersion4;	// Value for NSStreamSOCKProxyVersionKey
extern NSString * const NSStreamSOCKSProxyVersion5;	// Value for NSStreamSOCKProxyVersionKey

	// Key for obtaining the data written to a memory stream.
extern NSString * const NSStreamDataWrittenToMemoryStreamKey;

    // NSNumber representing the current absolute offset of the stream.
extern NSString * const NSStreamFileCurrentOffsetKey;

	// NSString constants for error domains.
extern NSString * const NSStreamSocketSSLErrorDomain;
    // SSL errors are to be interpreted via  Security/SecureTransport.h
extern NSString * const NSStreamSOCKSErrorDomain;

#endif /* NOT IMPLEMENTED ************************************************** */

#endif  /* _mGSTEP_H_NSStream */
