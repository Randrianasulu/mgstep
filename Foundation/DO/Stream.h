/*
   Stream.h

   Objective-C byte stream

   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.

   Author:	Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date:	July 1994

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_Stream
#define _mGSTEP_H_Stream

#include <Foundation/NSObject.h>

@class NSString;


/* ****************************************************************************

	Stream

** ***************************************************************************/

@protocol Streaming  <NSObject>

- (int) writeByte:(unsigned char)b;
- (int) readByte:(unsigned char*)b;

- (int) writeBytes:(const void*)b length:(int)l;
- (int) readBytes:(void*)b length:(int)l;

- (int) writeFormat:(NSString*)format, ...;
- (int) readFormat:(NSString*)format, ...;
- (int) writeFormat:(NSString*)format arguments:(va_list)arg;

@end


@interface Stream : NSObject
@end


@interface Stream (ConcreteStream)  <Streaming>
@end

/* ****************************************************************************

	MemoryStream

** ***************************************************************************/

@protocol MemoryStreaming  <Streaming>

- (unsigned) streamEofPosition;

@end


@interface MemoryStream : Stream
{
	id _data;
	int prefix;
	int position;
	int _eof;
	BOOL isMutable;
}

+ (MemoryStream*) streamWithData:(id)anObject;

- (id) initWithCapacity:(unsigned)capacity prefix:(unsigned)prefix;
- (id) initWithData:(id)anObject;

@end


@interface MemoryStream (ConcreteMemoryStream)  <MemoryStreaming>
@end

/* ****************************************************************************

	CStream

** ***************************************************************************/

@protocol CStreaming <Streaming>

- (void) encodeWithName:(NSString*)name
		 valuesOfCTypes:(const char *)types, ...;
- (void) decodeWithName:(NSString* *)name
		 valuesOfCTypes:(const char *)types, ...;

- (void) encodeName:(NSString*)name;
- (void) decodeName:(NSString* *)name;

- (void) encodeIndent;
- (void) decodeIndent;

- (void) encodeUnindent;
- (void) decodeUnindent;

- (id <Streaming>) stream;

@end


@interface CStream : Stream
{
	id <Streaming> _stream;
	int format_version;
	int indentation;
}

/* These are the standard ways to create a new CStream from a Stream
   that is open for reading.  It reads the CStream signature at the
   beginning of the file, and automatically creates the appropriate
   subclass of CStream with the correct format version.
*/
+ (id) cStreamReadingFromStream:(id <Streaming>)stream;

	// Std ways to create a new CStream with a Stream that is open for writing.
- (id) initForWritingToStream:(id <Streaming>)stream;

- (id) initForWritingToStream:(id <Streaming>)s
			withFormatVersion:(int)version;

	// designated initializer for reading.  Don't call it yourself.
- (id) _initForReadingFromPostSignatureStream:(id <Streaming>)s
							withFormatVersion:(int)version;

@end


@interface CStream (ConcreteCStream)  <CStreaming>

+ (int) defaultFormatVersion;

- (void) encodeValueOfCType:(const char*)type 
						 at:(const void*)d 
						 withName:(id)name;
- (void) decodeValueOfCType:(const char*)type 
						 at:(void*)d 
						 withName:(id *)namePtr;
@end

/* ****************************************************************************

	BinaryCStream

** ***************************************************************************/

@interface BinaryCStream : CStream
{
	unsigned char _sizeof_long;
	unsigned char _sizeof_int;
	unsigned char _sizeof_short;
	unsigned char _sizeof_char;
}

+ (void) _setDebugging:(BOOL)f;

@end

/* ****************************************************************************

	InPacket, OutPacket

** ***************************************************************************/

@interface InPacket : MemoryStream			// Objects for holding incoming or 
{											// outgoing data to/from ports.
	id _receiving_in_port;
	id _reply_out_port;
}

- (id) replyOutPort;
- (id) receivingInPort;

		// Do not call this method yourself; it is to be called by subclassers. 
		// InPackets are created for you by the InPort object, and are made 
		// available as the argument to the received packet invocation.
- (id) initForReceivingWithCapacity:(unsigned)s 
					receivingInPort:ip
					replyOutPort:op;
@end


@interface OutPacket : MemoryStream
{
	id _reply_in_port;
}

+ (unsigned) prefixSize;
- (id) initForSendingWithCapacity:(unsigned)c replyInPort:p;
- (id) replyInPort;

@end

#endif /* _mGSTEP_H_Stream */
