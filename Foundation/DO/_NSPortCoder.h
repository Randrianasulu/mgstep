/*
   _NSPortCoder.h

   Distributed Objects interface to PortCoder object

   Copyright (C) 1997 Free Software Foundation, Inc.

   Author:	Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date:	August 1997

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_PortCoder
#define _mGSTEP_H_PortCoder

#include <Foundation/NSPortCoder.h>
#include "Stream.h"

#define PACKAGE_NAME  "mGSTEP"
#define SIGNATURE_FORMAT_STRING  @"%s (%d) [%s %d]\n"

#define SIGNATURE_ARGS	PACKAGE_NAME, \
						PORT_CODER_FORMAT_VERSION, \
						[self defaultDecoderClassname], \
						format_version

#define PORT_CODER_FORMAT_VERSION 	((int) (mGSTEP_VERSION * 100000))

@class NSPort;
@class NSConnection;
@class InPacket;


/* ****************************************************************************

	Coding

** ***************************************************************************/

@protocol CommonCoding

- (BOOL) isDecoding;
+ (int) defaultFormatVersion;

@end


@protocol Encoding <CommonCoding>

- (void) encodeValueOfObjCType:(const char*)type 
							at:(const void*)d 
							withName:(id)name;

- (void) encodeValueOfCType:(const char*)type 
						 at:(const void*)d 
						 withName:(id)name;

- (void) encodeWithName:(id)name
		 valuesOfObjCTypes:(const char *)types, ...;

- (void) encodeArrayOfObjCType:(const char *)type
						 count:(unsigned)c
						 at:(const void *)d
						 withName:(id)name;

- (void) encodeObject:(id)anObj withName:(id)name;
- (void) encodeBycopyObject:(id)anObj withName:(id)name;
- (void) encodeByrefObject:(id)anObj withName:(id)name;

- (void) encodeRootObject:(id)anObj withName:(id)name;
- (void) encodeObjectReference:(id)anObj withName:(id)name;
- (void) startEncodingInterconnectedObjects;
- (void) finishEncodingInterconnectedObjects;

- (void) encodeAtomicString:(const char*)sp withName:(id)name;

- (void) encodeClass:aClass;

- (void) encodeName:(id)n;		// For inserting a name into a TextCoder stream

- (void) encodeIndent;			// For classes that want to track recursion
- (void) encodeUnindent;

- (void) encodeBytes:(const void *)b
			   count:(unsigned)c
			   withName:(id)name;

@end


@protocol Decoding <CommonCoding>

- (void) decodeValueOfObjCType:(const char*)type
							at:(void*)d 
							withName:(id *) namePtr;

- (void) decodeValueOfCType:(const char*)type
						 at:(void*)d 
						 withName:(id *)namePtr;

- (void) decodeWithName:(id *)name
	  valuesOfObjCTypes:(const char *)types, ...;

- (void) decodeArrayOfObjCType:(const char *)type
						 count:(unsigned)c
						 at:(void *)d
						 withName:(id *)name;

- (void) decodeObjectAt:(id*)anObjPtr withName:(id *)name;
- (void) startDecodingInterconnectedObjects;
- (void) finishDecodingInterconnectedObjects;
- (const char *) decodeAtomicStringWithName:(id *)name;
- decodeClass;

- (void) decodeName:(id *)n;	// For inserting a name into a TextCoder stream

- (void) decodeIndent;			// For classes that want to track recursion
- (void) decodeUnindent;

- (void) decodeBytes:(void *)b
			   count:(unsigned)c
			   withName:(id *)name;
@end


@interface NSPortCoder (mGSTEP)

+ (id) newForWritingWithConnection:(NSConnection*)c
					sequenceNumber:(int)n
						identifier:(int)i;

- (unsigned) sequenceNumber;
- (int) identifier;
- (void) dismiss;

- (id) _initWithCStream:(id <CStreaming>)cs formatVersion:(int)version;
- (NSUInteger) _coderReferenceForObject:(id)anObject;

@end


@interface PortEncoder : NSPortCoder
{
@public		// FIX ME in_progress_table should actually be an NSHashTable,
			// but we are working around a bug right now.
	NSMapTable *in_progress_table;	// objects begun writing, but !finished
	NSMapTable *object_2_xref;		// objects already written
	NSMapTable *object_2_fref;		// table of forward references
	NSMapTable *const_ptr_2_xref;	// const pointers already written
	unsigned fref_counter;			// Keep track of unused fref numbers
	BOOL _is_by_copy;
	BOOL _is_by_ref;
}

//+ newForWritingWithConnection:(NSConnection*)c
//			   sequenceNumber:(int)n
//			   identifier:(int)i;

+ (BOOL) encodeRootObject:(id)anObject 
				 withName:(NSString*) name
				 toStream:(id <Streaming>)stream;

+ (void) setDefaultStreamClass:(id)sc;						// Defaults
+ (void) setDefaultCStreamClass:(id)sc;
+ (id) defaultStreamClass;
+ (id) defaultCStreamClass;
+ (void) setDefaultFormatVersion:(int)fv;
+ (int) defaultFormatVersion;

- initForWritingToStream:(id <Streaming>)s;
- initForWritingToStream:(id <Streaming>)s
       withFormatVersion:(int)version
	   cStreamClass:(Class)cStreamClass
	   cStreamFormatVersion:(int)cStreamFormatVersion;

- _initForWritingWithConnection:(NSConnection*)c
				 sequenceNumber:(int)n
				 identifier:(int)i;

@end


@interface PortDecoder : NSPortCoder
{
	id xref_2_object;               // objects already read
	id xref_2_object_root;          // objs read since last -startDecodoingI.. 
	NSMapTable *xref_2_const_ptr;   // const pointers already written
	NSMapTable *fref_2_object;      // table of forward references
	NSMapTable *address_2_fref;     // table of forward references
}
			// These are class methods (and not instance methods) because the
			// header of the file or stream determines which subclass of 
			// Decoder is created.
+ newReadingFromStream:(id <Streaming>)stream;
+ decodeObjectWithName:(NSString **)name fromStream:(id <Streaming>)stream;

+ newDecodingWithPacket:(InPacket*)packet connection:(NSConnection*)c;
+ newDecodingWithConnection:(NSConnection*)c timeout:(int) timeout;
- (NSPort*) replyPort;

@end

						// Extensions to NSObject for encoding and decoding.
@interface NSObject (OptionalNewWithCoder)

+ newWithCoder:(NSPortCoder*)aDecoder;

@end


enum {
	CODER_OBJECT_NIL = 0, 
	CODER_OBJECT, 
	CODER_OBJECT_ROOT, 
	CODER_OBJECT_REPEATED, 
	CODER_OBJECT_FORWARD_REFERENCE,
	CODER_OBJECT_CLASS, 
	CODER_CLASS_NIL, 
	CODER_CLASS, 
	CODER_CLASS_REPEATED,
	CODER_CONST_PTR_NULL, 
	CODER_CONST_PTR, 
	CODER_CONST_PTR_REPEATED
};

#endif /* _mGSTEP_H_PortCoder */
